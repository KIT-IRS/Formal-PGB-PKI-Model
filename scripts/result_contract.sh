#!/usr/bin/env bash
# Shared ProVerif 2.05 result-contract checks. Source from an assertion runner.
# Expectations come from runner source, never from captured output or summaries.

pgb_contract_size=0
pgb_contract_files=()
pgb_contract_lines=()

pgb_contract_fail() {
  echo "error: result contract failed: $2" >&2
  cat -- "$1" >&2
  exit 1
}

pgb_prepare_results() {
  local result_file="$1"
  # Accept native-Windows CRLF and Unix LF. Preserve all other output text.
  local normalized="${result_file}.normalized"
  if ! LC_ALL=C awk '{ sub(/\r$/, ""); print }' "${result_file}" >"${normalized}"; then
    rm -f -- "${normalized}"
    pgb_contract_fail "${result_file}" "could not normalize line endings"
  fi
  mv -- "${normalized}" "${result_file}"
}

pgb_expect_result() {
  local result_file="$1"
  local expected="RESULT $2"
  local count i

  # A contract may contain only conclusive results, each exactly once.
  case "${expected}" in
    *' is true.'|*' is false.') ;;
    *) pgb_contract_fail "${result_file}" "invalid expectation: ${expected}" ;;
  esac
  for ((i = 0; i < pgb_contract_size; i++)); do
    if [[ "${pgb_contract_files[i]}" == "${result_file}" &&
          "${pgb_contract_lines[i]}" == "${expected}" ]]; then
      pgb_contract_fail "${result_file}" "duplicate expectation: ${expected}"
    fi
  done

  count="$(grep -Fxc -- "${expected}" "${result_file}" || true)"
  [[ "${count}" -eq 1 ]] ||
    pgb_contract_fail "${result_file}" "expected exactly one '${expected}'; found ${count}"
  pgb_contract_files[pgb_contract_size]="${result_file}"
  pgb_contract_lines[pgb_contract_size]="${expected}"
  pgb_contract_size=$((pgb_contract_size + 1))
}

pgb_expect_attacker() {
  local result_file="$1"
  local target="$2"
  local expected="$3"
  local predicate term
  # These are the naming conventions of the existing fixed 2.05 contracts.
  # Unknown target kinds fail closed; add an explicit typed expectation instead.
  case "${target}" in
    sk*) predicate=attacker_skey; term="${target}[]" ;;
    share[1-5]\(*) predicate=attacker_thresholdShare; term="${target}" ;;
    reach*|canary*) predicate=attacker_bitstring; term="${target}[]" ;;
    *) pgb_contract_fail "${result_file}" "unknown attacker target type: ${target}" ;;
  esac
  pgb_expect_result "${result_file}" "not ${predicate}(${term}) is ${expected}."
}

pgb_assert_complete() {
  local result_file="$1"
  local expected_count=0 actual_count i
  for ((i = 0; i < pgb_contract_size; i++)); do
    if [[ "${pgb_contract_files[i]}" == "${result_file}" ]]; then
      expected_count=$((expected_count + 1))
    fi
  done
  [[ "${expected_count}" -gt 0 ]] ||
    pgb_contract_fail "${result_file}" "empty result contract"
  # Each distinct expected line has already matched exactly once. Equal total
  # cardinality therefore excludes all extra/unknown/inconclusive RESULT lines.
  # Match RESULT without a following space to also reject malformed prefixes.
  actual_count="$(grep -c '^RESULT' "${result_file}" || true)"
  [[ "${actual_count}" -eq "${expected_count}" ]] ||
    pgb_contract_fail "${result_file}" \
      "unexpected RESULT lines: expected ${expected_count}, found ${actual_count}"
}
