#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
source "${script_dir}/result_contract.sh"
model_dir="${repo_root}/models/diagnostics"
lib_dir="${repo_root}/lib"
proverif_bin="${PROVERIF_BIN:-proverif}"
result_file="$(mktemp "${TMPDIR:-${model_dir}}/pgb-wrong-domain.XXXXXX")"
trap 'rm -f -- "${result_file}"' EXIT

"${proverif_bin}" -lib "${lib_dir}/common_primitives.pvl" \
  "${model_dir}/candidate_wrong_pgb_misbinding.pv" \
  >"${result_file}" 2>&1
pgb_prepare_results "${result_file}"
grep '^RESULT ' "${result_file}" || true

fail() { echo "error: $1" >&2; cat "${result_file}" >&2; exit 1; }
expect() { pgb_expect_result "${result_file}" "$1"; }

expect 'not attacker_skey(skCardA[]) is true.'
expect 'not attacker_skey(skCardB[]) is true.'
expect 'not attacker_skey(skDreg[]) is true.'
expect 'event(CandidateSelectedTarget(Dreg,Expected,Actual,Entry,Root)) ==> Expected = Actual is false.'
expect 'not event(WrongPGBTokenAccepted(Dreg,S)) is true.'
expect 'event(CorrectPGBTokenAccepted(Dreg,S)) ==> event(CardAuthorized(pgbA,Dreg,pk(skDreg[]),S)) is true.'
expect 'not attacker_bitstring(reachCorrectPGBAcceptance[]) is false.'
expect 'not attacker_bitstring(reachCandidateWrongPGBPresentation[]) is false.'

[[ "$(grep -c '^RESULT .* is true\.$' "${result_file}")" -eq 5 ]] || fail "expected 5 proved results"
[[ "$(grep -c '^RESULT .* is false\.$' "${result_file}")" -eq 3 ]] || fail "expected 3 expected-false results"
! grep -Eq '(^|[[:space:]])(Warning|Error):|^RESULT .* cannot be proved' "${result_file}" || fail "warning/error/inconclusive result"

pgb_assert_complete "${result_file}"

echo "PASS: 5 wrong-PGB containment properties and 3 expected misbinding/reachability results matched."
