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
result_dir="$(mktemp -d "${temp_parent%/}/pgb-pki-historical-accumulation.XXXXXX")"
trap 'rm -rf -- "${result_dir}"' EXIT
result_file="${result_dir}/reshare_historical_share_accumulation.out"

echo "==> reshare_historical_share_accumulation.pv"
if ! "${proverif_bin}" \
    -lib "${lib_dir}/common_primitives.pvl" \
    -lib "${lib_dir}/reshare_primitives.pvl" \
    "${model_dir}/reshare_historical_share_accumulation.pv" \
    >"${result_file}" 2>&1; then
  cat "${result_file}"
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

expect_exact_result 'not attacker_skey(skC3Device[]) is true.'
expect_exact_result 'not attacker_thresholdShare(share1(e0)) is false.'
expect_exact_result 'not attacker_thresholdShare(share2(e0)) is false.'
expect_exact_result 'not attacker_thresholdShare(share3(e0)) is true.'
expect_exact_result 'not attacker_thresholdShare(share1(e1)) is true.'
expect_exact_result 'not attacker_thresholdShare(share2(e1)) is true.'
expect_exact_result 'not attacker_thresholdShare(share3(e1)) is true.'
expect_exact_result 'not attacker_thresholdSignature(thresholdSig12(e0,regularLDevIDBody(tagRegularLDevID,pgbA,Dadv,pk(skAdv[]),regularMember,historicalRootSerial,historicalRootSerial))) is false.'
expect_exact_result 'event(HistoricalRootForgeryAccepted(Dadv,pk(skAdv[]),e0,S)) ==> event(CardAuthorized(pgbA,Dadv,pk(skAdv[]),S)) is false.'
expect_exact_result 'event(CommitteeActivated(E,PKRoot,S)) ==> PKRoot = pkChord is true.'
expect_exact_result 'event(RootContinuityAccepted(E,PKRoot,P,S)) ==> event(CommitteeActivated(E,PKRoot,S)) && PKRoot = pkChord is true.'
expect_exact_result 'not attacker_bitstring(reachFirstOldLeak[]) is false.'
expect_exact_result 'not attacker_bitstring(reachLegitimateReshare[]) is false.'
expect_exact_result 'not attacker_bitstring(reachSecondOldLeak[]) is false.'
expect_exact_result 'not attacker_bitstring(reachHistoricalForgery[]) is false.'

true_count="$(grep -c '^RESULT .* is true\.$' "${result_file}" || true)"
false_count="$(grep -c '^RESULT .* is false\.$' "${result_file}" || true)"
other_count="$(grep '^RESULT ' "${result_file}" | grep -Evc ' is (true|false)\.$' || true)"

[[ "${true_count}" -eq 7 ]] || fail_expectation "exactly 7 proved results"
[[ "${false_count}" -eq 8 ]] || fail_expectation "exactly 8 expected-false results"
[[ "${other_count}" -eq 0 ]] || fail_expectation "no inconclusive results"

if grep -Eq '(^|[[:space:]])(Warning|Error):' "${result_file}"; then
  fail_expectation "warning-free and error-free execution"
fi

pgb_assert_complete "${result_file}"

echo "PASS: all 7 historical-accumulation properties and 8 expected attack/reachability results matched."
