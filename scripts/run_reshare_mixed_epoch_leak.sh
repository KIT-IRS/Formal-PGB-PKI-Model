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
result_dir="$(mktemp -d "${temp_parent%/}/pgb-pki-reshare-mixed-epoch.XXXXXX")"
trap 'rm -rf -- "${result_dir}"' EXIT
result_file="${result_dir}/reshare_mixed_epoch_leak.out"

echo "==> reshare_mixed_epoch_leak.pv"
if ! "${proverif_bin}" \
    -lib "${lib_dir}/common_primitives.pvl" \
    -lib "${lib_dir}/reshare_primitives.pvl" \
    "${model_dir}/reshare_mixed_epoch_leak.pv" >"${result_file}" 2>&1; then
  cat "${result_file}"
  echo "error: ProVerif failed for reshare_mixed_epoch_leak.pv" >&2
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
  skCard skC1Device skC2Device skC3Device skO1Device \
  'share2(e0)' 'share3(e0)' 'share1(e1)' 'share3(e1)'; do
  expect_target "${target}" true
done

expect_exact_result 'not attacker_thresholdShare(share1(e0)) is false.'
expect_exact_result 'not attacker_thresholdShare(share2(e1)) is false.'
expect_exact_result 'not attacker_thresholdSignature(thresholdSig12(e0,regularLDevIDBody(tagRegularLDevID,pgbA,Dadv,pk(skAdv[]),regularMember,maliciousRootSerial,maliciousRootSerial))) is true.'
expect_exact_result 'not attacker_thresholdSignature(thresholdSig12(e1,regularLDevIDBody(tagRegularLDevID,pgbA,Dadv,pk(skAdv[]),regularMember,maliciousRootSerial,maliciousRootSerial))) is true.'
expect_exact_result 'not event(MixedEpochProposalAccepted(Dadv,pk(skAdv[]),maliciousAdmissionSerial,maliciousUpdateSerial)) is true.'
expect_exact_result 'event(RegularMembershipAuthorized(G,C3,PK,T,SAdmission,NCompletion)) ==> event(CardAuthorized(pgbA,C3,PK,T)) is true.'
expect_exact_result 'inj-event(CommitteePoPVerified(V,C3,PK,SAdmission,SUpdate,N)) ==> inj-event(CommitteePoPProduced(C3,PK,V,SAdmission,SUpdate,N)) is true.'
expect_exact_result 'event(CommitteeCandidateAuthenticated(V,D,PK,SAdmission,SUpdate)) ==> event(CertificationEligible(D,PK)) && event(RegularMembershipAuthorized(C1,D,PK,TAdmission,SAdmission,NCompletion)) && event(CommitteePoPVerified(V,D,PK,SAdmission,SUpdate,NCommittee)) is true.'
expect_exact_result 'event(CommitteeVote(V,e0,e1,D,PK,SAdmission,SUpdate)) ==> event(CommitteeCandidateAuthenticated(V,D,PK,SAdmission,SUpdate)) is true.'
expect_exact_result 'event(CommitteeApproved(e0,e1,D,PK,SAdmission,SUpdate)) ==> event(CommitteeVote(C2,e0,e1,D,PK,SAdmission,SUpdate)) && event(CertificationEligible(D,PK)) && event(RegularMembershipAuthorized(C1,D,PK,TAdmission,SAdmission,NCompletion)) is true.'
expect_exact_result 'event(ReshareStarted(E0,E1,D,PK,SAdmission,SUpdate)) ==> event(CommitteeApproved(E0,E1,D,PK,SAdmission,SUpdate)) is true.'
expect_exact_result 'event(ShareActivated(C3,E,pkChord,SUpdate)) ==> event(CertificationEligible(C3,PK)) && event(RegularMembershipAuthorized(C1,C3,PK,TAdmission,SAdmission,NCompletion)) && event(CommitteeApproved(e0,E,C3,PK,SAdmission,SUpdate)) is true.'
expect_exact_result 'event(ShareActivated(C1,E,pkChord,SUpdate)) ==> event(CommitteeApproved(e0,E,D,PK,SAdmission,SUpdate)) is true.'
expect_exact_result 'event(ShareActivated(C2,E,pkChord,SUpdate)) ==> event(CommitteeApproved(e0,E,D,PK,SAdmission,SUpdate)) is true.'
expect_exact_result 'event(CommitteeActivated(E,PKRoot,SUpdate)) ==> event(CommitteeApproved(e0,E,D,PK,SAdmission,SUpdate)) && event(ShareActivated(C1,E,PKRoot,SUpdate)) && event(ShareActivated(C2,E,PKRoot,SUpdate)) && event(ShareActivated(C3,E,PKRoot,SUpdate)) is true.'
expect_exact_result 'event(CommitteeActivated(E,PKRoot,SUpdate)) ==> PKRoot = pkChord is true.'
expect_exact_result 'event(RootContinuityAccepted(E,PKRoot,P,SUpdate)) ==> event(CommitteeActivated(E,PKRoot,SUpdate)) && PKRoot = pkChord is true.'
expect_exact_result 'not event(ShareActivated(O1,E,pkChord,S)) is true.'
expect_exact_result 'not event(ShareActivated(Dreg,E,pkChord,S)) is true.'
expect_target 'reachSetup' false
expect_target 'reachRegularMembershipAuthorized' false
expect_target 'reachCommitteeApproved' false
expect_target 'reachShareC1' false
expect_target 'reachShareC2' false
expect_target 'reachShareC3' false
expect_target 'reachCommitteeActivated' false
expect_target 'reachRootContinuity' false
expect_target 'reachOldShareLeak' false
expect_target 'reachNewShareLeak' false

true_count="$(grep -c '^RESULT .* is true\.$' "${result_file}" || true)"
false_count="$(grep -c '^RESULT .* is false\.$' "${result_file}" || true)"
other_count="$(grep '^RESULT ' "${result_file}" | grep -Evc ' is (true|false)\.$' || true)"

[[ "${true_count}" -eq 26 ]] || fail_expectation "exactly 26 proved results"
[[ "${false_count}" -eq 12 ]] || fail_expectation "exactly 12 expected-false results"
[[ "${other_count}" -eq 0 ]] || fail_expectation "no inconclusive results"

if grep -Eq '(^|[[:space:]])(Warning|Error):' "${result_file}"; then
  fail_expectation "warning-free and error-free execution"
fi

pgb_assert_complete "${result_file}"

echo "PASS: all 26 mixed-epoch properties and 12 compromise/reachability results matched."
