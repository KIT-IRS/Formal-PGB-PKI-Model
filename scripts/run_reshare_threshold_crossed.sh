#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
source "${script_dir}/result_contract.sh"
model_dir="${repo_root}/models/reshare"
lib_dir="${repo_root}/lib"
proverif_bin="${PROVERIF_BIN:-proverif}"

if ! command -v "${proverif_bin}" >/dev/null 2>&1; then
  echo "error: ProVerif executable not found: ${proverif_bin}" >&2
  exit 127
fi

temp_parent="${TMPDIR:-${model_dir}}"
result_dir="$(mktemp -d "${temp_parent%/}/pgb-pki-reshare-threshold-crossed.XXXXXX")"
trap 'rm -rf -- "${result_dir}"' EXIT
result_file="${result_dir}/reshare_threshold_crossed.out"

echo "==> reshare_threshold_crossed.pv"
if ! "${proverif_bin}" \
    -lib "${lib_dir}/common_primitives.pvl" \
    -lib "${lib_dir}/reshare_primitives.pvl" \
    "${model_dir}/reshare_threshold_crossed.pv" >"${result_file}" 2>&1; then
  cat "${result_file}"
  echo "error: ProVerif failed for reshare_threshold_crossed.pv" >&2
  exit 1
fi

pgb_prepare_results "${result_file}"
grep '^RESULT ' "${result_file}" || true

fail_expectation() {
  echo "error: result contract failed for $1" >&2
  cat "${result_file}" >&2
  exit 1
}

expect_exact_result() {
  pgb_expect_result "${result_file}" "$1"
}

expect_target() {
  pgb_expect_attacker "${result_file}" "$1" "$2"
}

for target in \
  skCard skC1Device skC2Device skO1Device \
  'share3(e0)' 'share1(e1)' 'share2(e1)'; do
  expect_target "${target}" true
done

expect_exact_result 'not attacker_thresholdShare(share1(e0)) is false.'
expect_exact_result 'not attacker_thresholdShare(share2(e0)) is false.'
expect_exact_result 'not attacker_thresholdShare(share3(e1)) is false.'
expect_exact_result 'event(CommitteeApproved(e0,e1,Dadv,pk(skAdv[]),maliciousAdmissionSerial,maliciousUpdateSerial)) ==> event(CommitteeVote(C1,e0,e1,Dadv,pk(skAdv[]),maliciousAdmissionSerial,maliciousUpdateSerial)) && event(CommitteeVote(C2,e0,e1,Dadv,pk(skAdv[]),maliciousAdmissionSerial,maliciousUpdateSerial)) is false.'
expect_exact_result 'event(CommitteeApproved(e0,e1,Dadv,pk(skAdv[]),maliciousAdmissionSerial,maliciousUpdateSerial)) ==> event(CertificationEligible(Dadv,pk(skAdv[]))) is false.'
expect_exact_result 'event(CommitteeApproved(e0,e1,Dadv,pk(skAdv[]),maliciousAdmissionSerial,maliciousUpdateSerial)) ==> event(RegularMembershipAuthorized(G,Dadv,pk(skAdv[]),T,maliciousAdmissionSerial,NCompletion)) is false.'
expect_exact_result 'event(ReshareStarted(E0,E1,D,PK,SAdmission,SUpdate)) ==> event(CommitteeApproved(E0,E1,D,PK,SAdmission,SUpdate)) is true.'
expect_exact_result 'event(ShareActivated(Dadv,e1,pkChord,SUpdate)) ==> event(CommitteeApproved(e0,e1,Dadv,pk(skAdv[]),maliciousAdmissionSerial,SUpdate)) is true.'
expect_exact_result 'event(ShareActivated(C1,e1,pkChord,SUpdate)) ==> event(CommitteeApproved(e0,e1,Dadv,pk(skAdv[]),maliciousAdmissionSerial,SUpdate)) is true.'
expect_exact_result 'event(ShareActivated(C2,e1,pkChord,SUpdate)) ==> event(CommitteeApproved(e0,e1,Dadv,pk(skAdv[]),maliciousAdmissionSerial,SUpdate)) is true.'
expect_exact_result 'event(CommitteeActivated(E,PKRoot,SUpdate)) ==> event(CommitteeApproved(e0,E,Dadv,pk(skAdv[]),maliciousAdmissionSerial,SUpdate)) && event(ShareActivated(C1,E,PKRoot,SUpdate)) && event(ShareActivated(C2,E,PKRoot,SUpdate)) && event(ShareActivated(Dadv,E,PKRoot,SUpdate)) is true.'
expect_exact_result 'event(CommitteeActivated(E,PKRoot,SUpdate)) ==> PKRoot = pkChord is true.'
expect_exact_result 'event(RootContinuityAccepted(E,PKRoot,P,SUpdate)) ==> event(CommitteeActivated(E,PKRoot,SUpdate)) && PKRoot = pkChord is true.'
expect_exact_result 'not event(ShareActivated(C3,e1,pkChord,S)) is true.'
expect_exact_result 'not event(ShareActivated(O1,E,pkChord,S)) is true.'
expect_target 'reachSetup' false
expect_target 'reachShare1Leak' false
expect_target 'reachShare2Leak' false
expect_target 'reachMaliciousApproval' false
expect_target 'reachShareC1' false
expect_target 'reachShareC2' false
expect_target 'reachShareDadv' false
expect_target 'reachMaliciousCommittee' false
expect_target 'reachRootContinuity' false

true_count="$(grep -c '^RESULT .* is true\.$' "${result_file}" || true)"
false_count="$(grep -c '^RESULT .* is false\.$' "${result_file}" || true)"
other_count="$(grep '^RESULT ' "${result_file}" | grep -Evc ' is (true|false)\.$' || true)"

[[ "${true_count}" -eq 16 ]] || fail_expectation "exactly 16 proved results"
[[ "${false_count}" -eq 15 ]] || fail_expectation "exactly 15 expected-false results"
[[ "${other_count}" -eq 0 ]] || fail_expectation "no inconclusive results"

if grep -Eq '(^|[[:space:]])(Warning|Error):' "${result_file}"; then
  fail_expectation "warning-free and error-free execution"
fi

pgb_assert_complete "${result_file}"

echo "PASS: all 16 contained properties and 15 threshold-crossing attack/compromise/reachability results matched."
