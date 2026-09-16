#!/usr/bin/env bash
set -euo pipefail

# Run the PGB-PKI two-share threshold-crossing negative control and assert its
# complete result contract. Override PROVERIF_BIN if needed.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
source "${script_dir}/result_contract.sh"
model_dir="${repo_root}/models/regular"
lib_dir="${repo_root}/lib"
proverif_bin="${PROVERIF_BIN:-proverif}"

if ! command -v "${proverif_bin}" >/dev/null 2>&1; then
  echo "error: ProVerif executable not found: ${proverif_bin}" >&2
  echo "install ProVerif 2.05 or set PROVERIF_BIN=/path/to/proverif" >&2
  exit 127
fi

temp_parent="${TMPDIR:-${model_dir}}"
result_dir="$(mktemp -d "${temp_parent%/}/pgb-pki-leak-two-shares.XXXXXX")"
trap 'rm -rf -- "${result_dir}"' EXIT
result_file="${result_dir}/regular_2of3_leak_two_shares.out"

echo "==> regular_2of3_leak_two_shares.pv"
if ! "${proverif_bin}" \
    -lib "${lib_dir}/common_primitives.pvl" \
    "${model_dir}/regular_2of3_leak_two_shares.pv" \
    >"${result_file}" 2>&1; then
  cat "${result_file}"
  echo "error: ProVerif failed while running the two-share model" >&2
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

# All authority/device keys and the non-leaked third share remain secret.
for target in \
  skCard skC1Device skC2Device skC3Device skO1Device skDregDevice \
  'share3(e0)'; do
  expect_target "${target}" true
done

# Threshold crossing is explicit.
expect_target 'share1(e0)' false
expect_target 'share2(e0)' false

# Principal negative result and pair-specific residual controls.
expect_exact_result \
  'event(RegularMembershipAuthorized(G,D,PK,T,S,NJ)) ==> event(CardAuthorized(pgbA,D,PK,T)) is false.'
expect_exact_result \
  'event(RegularCredentialAccepted12(G,D,PK,T,S,NJ)) ==> event(CardAuthorized(pgbA,D,PK,T)) is false.'
expect_exact_result \
  'event(RegularCredentialAccepted13(G,D,PK,T,S,NJ)) ==> event(CardAuthorized(pgbA,D,PK,T)) is true.'
expect_exact_result \
  'event(RegularCredentialAccepted23(G,D,PK,T,S,NJ)) ==> event(CardAuthorized(pgbA,D,PK,T)) is true.'

expect_exact_result \
  'event(RegularMembershipAuthorized(G,D,PK,T,S,NJ)) ==> event(PGBLocked(pgbA)) is true.'


expect_exact_result \
  'inj-event(SignerValidated(Ci,D,PK,T,S,E,N)) ==> inj-event(RegularSignerPoPVerified(Ci,D,PK,S,E,N)) is true.'
expect_exact_result \
  'inj-event(SignerValidated(Ci,D,PK,T,S,E,N)) ==> inj-event(RegularPoPProduced(D,PK,Ci,S,N)) is true.'
expect_exact_result \
  'event(SignerValidated(Ci,D,PK,T,S,E,N)) ==> event(CardAuthorized(pgbA,D,PK,T)) is true.'
expect_exact_result \
  'event(PartialIssued(Ci,D,PK,S,E)) ==> event(SignerValidated(Ci,D,PK,T,S,E,N)) is true.'

# Only C3 remains uncompromised in the pair13/pair23 paths.
expect_exact_result \
  'event(RegularCredentialAccepted13(G,D,PK,T,S,NJ)) ==> event(SignerValidated(C3,D,PK,T,S,e0,N3)) is true.'
expect_exact_result \
  'event(RegularCredentialAccepted23(G,D,PK,T,S,NJ)) ==> event(SignerValidated(C3,D,PK,T,S,e0,N3)) is true.'

# Structural nonreachability: no share-activation service is instantiated.
expect_exact_result 'not event(ShareActivated(O1,E,pkChord,S)) is true.'
expect_exact_result 'not event(ShareActivated(Dreg,E,pkChord,S)) is true.'

# False is intentional: setup, both leaks, honest Dreg/key reachability, and the Dadv
# attack trace must all be reachable.
for target in \
  reachSetup reachShare1Leak reachShare2Leak reachRepresentativeOverlayForwarding \
  reachHonestDregPair12MembershipAuthorized reachHonestDregPair13MembershipAuthorized reachHonestDregPair23MembershipAuthorized \
  reachUnauthorizedDadvMembershipAuthorized; do
  expect_target "${target}" false
done

result_count="$(grep -c '^RESULT ' "${result_file}" || true)"
if [[ "${result_count}" -ne 30 ]]; then
  fail_expectation "exactly 30 results (found ${result_count})"
fi

if grep -Eq '(^|[[:space:]])(Warning|Error):' "${result_file}"; then
  fail_expectation "warning-free and error-free execution"
fi

pgb_assert_complete "${result_file}"

echo "PASS: all 18 proved and 12 expected attack/compromise/reachability results matched."
