#!/usr/bin/env bash
set -euo pipefail

# Run the post-lock peer-authentication model and assert its complete result
# contract, including the isolated Dleak device-key compromise.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
source "${script_dir}/result_contract.sh"
model_dir="${repo_root}/models/peer"
lib_dir="${repo_root}/lib"
proverif_bin="${PROVERIF_BIN:-proverif}"

if ! command -v "${proverif_bin}" >/dev/null 2>&1; then
  echo "error: ProVerif executable not found: ${proverif_bin}" >&2
  echo "install ProVerif 2.05 or set PROVERIF_BIN=/path/to/proverif" >&2
  exit 127
fi

temp_parent="${TMPDIR:-${model_dir}}"
result_dir="$(mktemp -d "${temp_parent%/}/pgb-pki-peer-auth.XXXXXX")"
trap 'rm -rf -- "${result_dir}"' EXIT
result_file="${result_dir}/peer_authentication.out"

echo "==> peer_authentication.pv"
if ! "${proverif_bin}" \
    -lib "${lib_dir}/common_primitives.pvl" \
    "${model_dir}/peer_authentication.pv" \
    >"${result_file}" 2>&1; then
  cat "${result_file}"
  echo "error: ProVerif failed while running peer authentication" >&2
  exit 1
fi

pgb_prepare_results "${result_file}"
grep '^RESULT ' "${result_file}" || true

fail_expectation() {
  local description="$1"
  echo "error: result contract failed for ${description}" >&2
  echo "full ProVerif output follows" >&2
  cat "${result_file}" >&2
  exit 1
}

expect_target() {
  pgb_expect_attacker "${result_file}" "$1" "$2"
}

expect_exact_result() {
  pgb_expect_result "${result_file}" "$1"
}

# Only Dleak's endpoint key is deliberately disclosed.
expect_target skDleakDevice false

for target in \
  skCard skC1Device skO1Device skDregDevice skDemgDevice \
  'share1(e0)' 'share2(e0)' 'share3(e0)'; do
  expect_target "${target}" true
done

expect_exact_result 'event(PeerAcceptedByInitiator(C1,pk(skC1Device[]),Demg,pk(skDemgDevice[]),S,NA,NB)) ==> event(PGBILDevIDWithCAIssued(C1,pk(skC1Device[]),pgbiIssuerSerial)) && event(PGBILDevIDCAValidated(C1,C1,pk(skC1Device[]),pgbiIssuerSerial)) is true.'
expect_exact_result 'event(PeerAcceptedByResponder(C1,pk(skC1Device[]),Demg,pk(skDemgDevice[]),S,NA,NB)) ==> event(PGBILDevIDWithCAIssued(C1,pk(skC1Device[]),pgbiIssuerSerial)) && event(PGBILDevIDCAValidated(C1,C1,pk(skC1Device[]),pgbiIssuerSerial)) is true.'

# Structural absence checks: no signing/activation service runs in this model.
expect_exact_result 'not event(ShareActivated(Dleak,E,pkChord,S)) is true.'
expect_exact_result 'not event(PartialIssued(Dleak,Dleak,PK,S,E)) is true.'

# Regular->regular, emergency->regular, and regular->emergency baselines.
expect_exact_result 'inj-event(PeerAcceptedByInitiator(Dreg,pk(skDregDevice[]),O1,pk(skO1Device[]),S,NA,NB)) ==> inj-event(PeerAuthResponded(O1,pk(skO1Device[]),Dreg,pk(skDregDevice[]),S,NA,NB)) is true.'
expect_exact_result 'inj-event(PeerAcceptedByResponder(O1,pk(skO1Device[]),Dreg,pk(skDregDevice[]),S,NA,NB)) ==> inj-event(PeerAuthFinalized(Dreg,pk(skDregDevice[]),O1,pk(skO1Device[]),S,NA,NB)) is true.'
expect_exact_result 'inj-event(PeerAuthFinalized(Dreg,pk(skDregDevice[]),O1,pk(skO1Device[]),S,NA,NB)) ==> inj-event(PeerAuthStarted(Dreg,pk(skDregDevice[]),O1,S,NA)) is true.'

expect_exact_result 'inj-event(PeerAcceptedByInitiator(Demg,pk(skDemgDevice[]),C1,pk(skC1Device[]),S,NA,NB)) ==> inj-event(PeerAuthResponded(C1,pk(skC1Device[]),Demg,pk(skDemgDevice[]),S,NA,NB)) is true.'
expect_exact_result 'inj-event(PeerAcceptedByResponder(C1,pk(skC1Device[]),Demg,pk(skDemgDevice[]),S,NA,NB)) ==> inj-event(PeerAuthFinalized(Demg,pk(skDemgDevice[]),C1,pk(skC1Device[]),S,NA,NB)) is true.'
expect_exact_result 'inj-event(PeerAuthFinalized(Demg,pk(skDemgDevice[]),C1,pk(skC1Device[]),S,NA,NB)) ==> inj-event(PeerAuthStarted(Demg,pk(skDemgDevice[]),C1,S,NA)) is true.'

expect_exact_result 'inj-event(PeerAcceptedByInitiator(C1,pk(skC1Device[]),Demg,pk(skDemgDevice[]),S,NA,NB)) ==> inj-event(PeerAuthResponded(Demg,pk(skDemgDevice[]),C1,pk(skC1Device[]),S,NA,NB)) is true.'
expect_exact_result 'inj-event(PeerAcceptedByResponder(Demg,pk(skDemgDevice[]),C1,pk(skC1Device[]),S,NA,NB)) ==> inj-event(PeerAuthFinalized(C1,pk(skC1Device[]),Demg,pk(skDemgDevice[]),S,NA,NB)) is true.'
expect_exact_result 'inj-event(PeerAuthFinalized(C1,pk(skC1Device[]),Demg,pk(skDemgDevice[]),S,NA,NB)) ==> inj-event(PeerAuthStarted(C1,pk(skC1Device[]),Demg,S,NA)) is true.'

# The uncompromised peer remains authenticated in both Dleak sessions.
expect_exact_result 'inj-event(PeerAcceptedByResponder(Dleak,pk(skDleakDevice[]),C1,pk(skC1Device[]),S,NA,NB)) ==> inj-event(PeerAuthFinalized(C1,pk(skC1Device[]),Dleak,pk(skDleakDevice[]),S,NA,NB)) is true.'
expect_exact_result 'inj-event(PeerAcceptedByInitiator(Dleak,pk(skDleakDevice[]),O1,pk(skO1Device[]),S,NA,NB)) ==> inj-event(PeerAuthResponded(O1,pk(skO1Device[]),Dleak,pk(skDleakDevice[]),S,NA,NB)) is true.'

# Only Dleak-origin claims fail after the selected endpoint-key disclosure.
expect_exact_result 'event(PeerAcceptedByInitiator(C1,pk(skC1Device[]),Dleak,pk(skDleakDevice[]),S,NA,NB)) ==> event(PeerAuthResponded(Dleak,pk(skDleakDevice[]),C1,pk(skC1Device[]),S,NA,NB)) is false.'
expect_exact_result 'event(PeerAcceptedByResponder(O1,pk(skO1Device[]),Dleak,pk(skDleakDevice[]),S,NA,NB)) ==> event(PeerAuthFinalized(Dleak,pk(skDleakDevice[]),O1,pk(skO1Device[]),S,NA,NB)) is false.'

for target in \
  reachSetup reachDleakKeyLeak \
  reachRRInitiatorAccepted reachRRResponderAccepted \
  reachERInitiatorAccepted reachERResponderAccepted \
  reachREInitiatorAccepted reachREResponderAccepted \
  reachC1AcceptsDleak reachDleakAcceptsC1 \
  reachDleakAcceptsO1 reachO1AcceptsDleak; do
  expect_target "${target}" false
done

result_count="$(grep -c '^RESULT ' "${result_file}" || true)"
if [[ "${result_count}" -ne 38 ]]; then
  fail_expectation "exactly 38 results (found ${result_count})"
fi

if grep -Eq '(^|[[:space:]])(Warning|Error):' "${result_file}"; then
  fail_expectation "warning-free and error-free execution"
fi

pgb_assert_complete "${result_file}"

echo "PASS: all 23 proved and 15 expected compromise/attack/reachability results matched."
