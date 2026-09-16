#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
source "${script_dir}/result_contract.sh"
proverif_bin="${PROVERIF_BIN:-proverif}"
result_file="$(mktemp "${TMPDIR:-/tmp}/pgb-emergency-containment.XXXXXX")"
trap 'rm -f -- "${result_file}"' EXIT
if "${proverif_bin}" -lib "${repo_root}/lib/common_primitives.pvl" \
  -lib "${repo_root}/lib/reshare_primitives.pvl" \
  -lib "${repo_root}/lib/emergency_containment_processes.pvl" \
  "${repo_root}/models/emergency/emergency_containment_no_class_gate.pv" >"${result_file}" 2>&1; then
  :
else
  verifier_status=$?
  echo "error: ProVerif failed in ${BASH_SOURCE[0]##*/} (exit ${verifier_status})" >&2
  cat -- "${result_file}" >&2
  exit "${verifier_status}"
fi
pgb_prepare_results "${result_file}"
grep '^RESULT ' "${result_file}" || true
# Intended PV 2.05 contracts: require a real verifier run before claiming proof.
expect() { pgb_expect_result "${result_file}" "$1"; }
# Key/share knowledge; the compromised C1 also receives its e1 share.
expect 'not attacker_skey(skCard[]) is true.'
expect 'not attacker_skey(skC1Device[]) is false.'
expect 'not attacker_skey(skC2Device[]) is true.'
expect 'not attacker_skey(skDregDevice[]) is true.'
expect 'not attacker_thresholdShare(share1(e0)) is false.'
expect 'not attacker_thresholdShare(share2(e0)) is true.'
expect 'not attacker_thresholdShare(share1(e1)) is false.'
expect 'not attacker_thresholdShare(share2(e1)) is true.'
expect 'not attacker_thresholdShare(share3(e1)) is false.'
# End-to-end provenance across live public services.
expect 'event(ContainmentHonestPartial(D,PK)) ==> event(ContainmentCardGrant(D,PK)) is true.'
expect 'event(ContainmentRegularAccepted(D,PK)) ==> event(ContainmentCardGrant(D,PK)) is false.'
expect 'event(ContainmentApproved(D,PK)) ==> event(ContainmentRegularEvidence(D,PK)) is false.'
expect 'event(ContainmentApproved(D,PK)) ==> event(ContainmentEligible(D,PK)) is true.'
expect 'event(ContainmentDelivered(D,PK)) ==> event(ContainmentApproved(D,PK)) is true.'
# Concrete Dadv escalation; honest regular signing stays card-gated in both variants.
expect 'not event(ContainmentAttackRegular(Dadv)) is false.'
expect 'not event(ContainmentAttackPartial(Dadv)) is true.'
expect 'not event(ContainmentAttackVote(Dadv)) is false.'
expect 'not event(ContainmentAttackApproved(Dadv)) is false.'
expect 'not event(ContainmentAttackDelivered(Dadv)) is false.'
expect 'not event(ContainmentAttackActivated(Dadv)) is false.'
# Honest milestones and real attacker requests must all be reachable.
expect 'not attacker_bitstring(reachContainmentEmergency[]) is false.'
expect 'not attacker_bitstring(reachContainmentAdmissionAttempt[]) is false.'
expect 'not attacker_bitstring(reachContainmentCommitteeAttempt[]) is false.'
expect 'not attacker_bitstring(reachContainmentRegular[]) is false.'
expect 'not attacker_bitstring(reachContainmentHonestPartial[]) is false.'
expect 'not attacker_bitstring(reachContainmentHonestVote[]) is false.'
expect 'not attacker_bitstring(reachContainmentApproved[]) is false.'
expect 'not attacker_bitstring(reachContainmentDelivered[]) is false.'
expect 'not attacker_bitstring(reachContainmentActivated[]) is false.'
# Escalation canaries are secret in the reference policy, public in the negative control.
expect 'not attacker_bitstring(reachContainmentAttackApproved[]) is false.'
expect 'not attacker_bitstring(reachContainmentAttackDelivered[]) is false.'
expect 'not attacker_bitstring(reachContainmentAttackActivated[]) is false.'
if grep -Eq '(^|[[:space:]])(Warning|Error):|^RESULT .* cannot be proved' "${result_file}"; then
  cat "${result_file}" >&2
  exit 1
fi
pgb_assert_complete "${result_file}"
echo "PASS: emergency_containment_no_class_gate: all 32 expected results matched."
