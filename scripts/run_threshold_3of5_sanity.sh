#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
source "${script_dir}/result_contract.sh"
model_dir="${repo_root}/models/threshold"
lib_dir="${repo_root}/lib"
proverif_bin="${PROVERIF_BIN:-proverif}"
result_file="$(mktemp "${TMPDIR:-${model_dir}}/pgb-threshold-3of5.XXXXXX")"
trap 'rm -f -- "${result_file}"' EXIT

"${proverif_bin}" -lib "${lib_dir}/common_primitives.pvl" \
  -lib "${lib_dir}/threshold_3of5_primitives.pvl" \
  "${model_dir}/threshold_3of5_sanity.pv" >"${result_file}" 2>&1
pgb_prepare_results "${result_file}"
grep '^RESULT ' "${result_file}" || true

fail() { echo "error: $1" >&2; cat "${result_file}" >&2; exit 1; }
expect() { pgb_expect_result "${result_file}" "$1"; }

for target in 'share1(e35)' 'share2(e35)' 'share3(e35)' 'share4(e35)' 'share5(e35)'; do
  expect "not attacker_thresholdShare(${target}) is true."
done
for target in reach123 reach124 reach125 reach134 reach135 reach145 reach234 reach235 reach245 reach345; do
  expect "not attacker_bitstring(${target}[]) is false."
done
for target in canaryPairOnly canaryDuplicate canaryMixedEpoch canaryMixedMessage canaryWrongRoot; do
  expect "not attacker_bitstring(${target}[]) is true."
done

[[ "$(grep -c '^RESULT .* is true\.$' "${result_file}")" -eq 10 ]] || fail "expected 10 proved results"
[[ "$(grep -c '^RESULT .* is false\.$' "${result_file}")" -eq 10 ]] || fail "expected 10 reachability results"
! grep -Eq '(^|[[:space:]])(Warning|Error):|^RESULT .* cannot be proved' "${result_file}" || fail "warning/error/inconclusive result"

pgb_assert_complete "${result_file}"

echo "PASS: all 10 valid 3-of-5 triples and 10 safety/secrecy checks matched."
