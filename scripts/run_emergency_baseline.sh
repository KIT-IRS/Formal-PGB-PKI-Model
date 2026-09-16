#!/usr/bin/env bash
set -euo pipefail

# Run the restricted emergency-path baseline and assert its complete contract.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
source "${script_dir}/result_contract.sh"
model_dir="${repo_root}/models/emergency"
lib_dir="${repo_root}/lib"
proverif_bin="${PROVERIF_BIN:-proverif}"

if ! command -v "${proverif_bin}" >/dev/null 2>&1; then
  echo "error: ProVerif executable not found: ${proverif_bin}" >&2
  echo "install ProVerif 2.05 or set PROVERIF_BIN=/path/to/proverif" >&2
  exit 127
fi

temp_parent="${TMPDIR:-${model_dir}}"
result_dir="$(mktemp -d "${temp_parent%/}/pgb-pki-emergency-baseline.XXXXXX")"
trap 'rm -rf -- "${result_dir}"' EXIT
result_file="${result_dir}/emergency_baseline.out"

echo "==> emergency_baseline.pv"
if ! "${proverif_bin}" \
    -lib "${lib_dir}/common_primitives.pvl" \
    "${model_dir}/emergency_baseline.pv" \
    >"${result_file}" 2>&1; then
  cat "${result_file}"
  echo "error: ProVerif failed while running the emergency baseline" >&2
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

for target in \
  skCard skPlant skC1Device skC2Device skC3Device \
  skO1Device skDemgDevice \
  'share1(e0)' 'share2(e0)' 'share3(e0)'; do
  expect_target "${target}" true
done

expect_exact_result 'event(EmergencyCredentialAccepted(G,D,PK,SIssuer,S)) ==> event(EmergencyCredentialIssued(C1,D,PK,S)) && event(PlantCredentialValidated(C1,D,PK,SPlant,S)) is true.'
expect_exact_result 'event(EmergencyCredentialAccepted(G,D,PK,SIssuer,S)) ==> event(PGBILDevIDCAValidated(G,C1,pk(skC1Device[]),SIssuer)) is true.'
expect_exact_result 'event(EmergencyOverlayJoined(G,D,PK,SIssuer,S)) ==> event(EmergencyCredentialAccepted(G,D,PK,SIssuer,S)) is true.'
expect_exact_result 'event(EmergencyOverlayJoined(G,D,PK,SIssuer,S)) ==> event(PGBLocked(pgbA)) is true.'
expect_exact_result 'event(PGBILDevIDCAValidated(G,C1,PK,SIssuer)) ==> event(PGBILDevIDWithCAIssued(C1,PK,SIssuer)) is true.'
expect_exact_result 'event(EmergencyCredentialIssued(P,D,PK,S)) ==> event(PlantCredentialValidated(P,D,PK,SPlant,S)) is true.'
expect_exact_result 'event(PlantCredentialValidated(P,D,PK,SPlant,S)) ==> event(PlantCredentialProvisioned(D,PK,SPlant)) is true.'
expect_exact_result 'inj-event(PlantCredentialValidated(P,D,PK,SPlant,S)) ==> inj-event(EmergencyPoPVerified(P,D,PK,SPlant,S,N)) is true.'
expect_exact_result 'inj-event(PlantCredentialValidated(P,D,PK,SPlant,S)) ==> inj-event(EmergencyPoPProduced(D,PK,P,SPlant,S,N)) is true.'

# Structural absence checks; no live regular/committee services are composed here.
expect_exact_result 'not event(RegularMembershipAuthorized(G,Demg,PK,T,S,N)) is true.'
expect_exact_result 'not event(PartialIssued(C1,Demg,PK,S,E)) is true.'
expect_exact_result 'not event(ShareActivated(Demg,E,pkChord,S)) is true.'
expect_exact_result 'not event(CommitteeApproved(E0,E1,Demg,PK,SAdmission,SUpdate)) is true.'
expect_exact_result 'not attacker_thresholdSignature(thresholdSig12(e0,regularLDevIDBody(tagRegularLDevID,pgbA,Demg,pk(skDemgDevice[]),regularMember,regularForgerySerial,regularForgerySerial))) is true.'

for target in \
  reachSetup reachPlantProvisioned reachEmergencyIssued \
  reachEmergencyJoinRequested reachEmergencyCredentialAccepted \
  reachEmergencyOverlayJoined; do
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

echo "PASS: all 24 proved and 6 expected reachability results matched."
