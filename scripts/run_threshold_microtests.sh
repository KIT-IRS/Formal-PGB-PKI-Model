#!/usr/bin/env bash
set -euo pipefail

# Run the PGB-PKI 2-of-3 threshold micro-test suite and assert its result
# polarity. Override PROVERIF_BIN if the executable is not named "proverif".

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
source "${script_dir}/result_contract.sh"
microtest_dir="${repo_root}/models/threshold"
lib_dir="${repo_root}/lib"
proverif_bin="${PROVERIF_BIN:-proverif}"

if ! command -v "${proverif_bin}" >/dev/null 2>&1; then
  echo "error: ProVerif executable not found: ${proverif_bin}" >&2
  echo "install ProVerif 2.05+ or set PROVERIF_BIN=/path/to/proverif" >&2
  exit 127
fi

temp_parent="${TMPDIR:-${microtest_dir}}"
result_dir="$(mktemp -d "${temp_parent%/}/pgb-pki-threshold.XXXXXX")"
trap 'rm -rf -- "${result_dir}"' EXIT

run_model() {
  local model_name="$1"
  local result_file="$2"

  echo "==> ${model_name}"
  if ! "${proverif_bin}" \
      -lib "${lib_dir}/common_primitives.pvl" \
      "${microtest_dir}/${model_name}" \
      >"${result_file}" 2>&1; then
    cat "${result_file}"
    echo "error: ProVerif failed while running ${model_name}" >&2
    exit 1
  fi

  pgb_prepare_results "${result_file}"
  grep '^RESULT ' "${result_file}" || true
}

expect_result() {
  pgb_expect_attacker "$1" "$2" "$3"
}

safety_result="${result_dir}/safety.out"
liveness_result="${result_dir}/liveness.out"

run_model threshold_micro_safety.pv "${safety_result}"

expect_result "${safety_result}" canary_one_share true
expect_result "${safety_result}" canary_duplicate_share true
expect_result "${safety_result}" canary_mixed_epoch true
expect_result "${safety_result}" canary_message_left true
expect_result "${safety_result}" canary_message_right true
expect_result "${safety_result}" canary_noncert_unit true
expect_result "${safety_result}" 'share1(e_message_binding)' true
expect_result "${safety_result}" 'share2(e_message_binding)' true

run_model threshold_micro_liveness.pv "${liveness_result}"

# False is intentional here: it witnesses successful 2-share construction.
expect_result "${liveness_result}" canary_pair12 false
expect_result "${liveness_result}" canary_pair13 false
expect_result "${liveness_result}" canary_pair23 false

expect_result "${liveness_result}" canary_wrong_root_key true
expect_result "${liveness_result}" 'share3(e_pair12)' true
expect_result "${liveness_result}" 'share2(e_pair13)' true
expect_result "${liveness_result}" 'share1(e_pair23)' true

safety_result_count="$(grep -c '^RESULT ' "${safety_result}" || true)"
if [[ "${safety_result_count}" -ne 8 ]]; then
  echo "error: expected exactly 8 safety results; found ${safety_result_count}" >&2
  cat "${safety_result}" >&2
  exit 1
fi

liveness_result_count="$(grep -c '^RESULT ' "${liveness_result}" || true)"
if [[ "${liveness_result_count}" -ne 7 ]]; then
  echo "error: expected exactly 7 liveness results; found ${liveness_result_count}" >&2
  cat "${liveness_result}" >&2
  exit 1
fi

if grep -Eiq '(^|[^[:alpha:]])(warning|error)([^[:alpha:]]|$)' \
    "${safety_result}" "${liveness_result}"; then
  echo "error: threshold micro-tests produced a warning or error" >&2
  cat "${safety_result}" >&2
  cat "${liveness_result}" >&2
  exit 1
fi

pgb_assert_complete "${safety_result}"
pgb_assert_complete "${liveness_result}"

echo "PASS: all 12 proved and 3 expected liveness results matched."
