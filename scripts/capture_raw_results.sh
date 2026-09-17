#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
model_root="${repo_root}/models"
lib_dir="${repo_root}/lib"
proverif_bin="${PROVERIF_BIN:-proverif}"
output_dir="${1:-${repo_root}/outputs}"

if ! command -v "${proverif_bin}" >/dev/null 2>&1; then
  echo "error: ProVerif executable not found: ${proverif_bin}" >&2
  exit 127
fi

if [[ -d "${output_dir}" ]] && find "${output_dir}" -mindepth 1 -print -quit | grep -q .; then
  echo "error: output directory is not empty: ${output_dir}" >&2
  exit 1
fi

mkdir -p "${output_dir}"

declare -A expected_result_counts=(
  [candidate_wrong_pgb_misbinding.pv]=8
  [emergency_containment.pv]=32
  [emergency_containment_no_class_gate.pv]=32
  [emergency_baseline.pv]=30
  [emergency_pgbi_compromised.pv]=37
  [integrated_smoke.pv]=45
  [peer_authentication.pv]=38
  [post_reshare_e1_issuance.pv]=17
  [regular_2of3_baseline.pv]=26
  [regular_2of3_leak_card.pv]=32
  [regular_2of3_leak_share1.pv]=26
  [regular_2of3_leak_share1_c1_offline.pv]=26
  [regular_2of3_leak_two_shares.pv]=30
  [regular_2of3_no_pop_or_binding.pv]=32
  [regular_token_one_time_consumption.pv]=8
  [reshare_2to3_baseline.pv]=33
  [reshare_2to3_leak_share1.pv]=36
  [reshare_historical_share_accumulation.pv]=15
  [reshare_mixed_epoch_leak.pv]=38
  [reshare_threshold_crossed.pv]=31
  [threshold_3of5_sanity.pv]=20
  [threshold_micro_liveness.pv]=7
  [threshold_micro_safety.pv]=8
)

model_paths=(
  "${model_root}/diagnostics/candidate_wrong_pgb_misbinding.pv"
  "${model_root}/emergency/emergency_containment.pv"
  "${model_root}/emergency/emergency_containment_no_class_gate.pv"
  "${model_root}/emergency/emergency_baseline.pv"
  "${model_root}/emergency/emergency_pgbi_compromised.pv"
  "${model_root}/integration/integrated_smoke.pv"
  "${model_root}/peer/peer_authentication.pv"
  "${model_root}/regular/regular_2of3_baseline.pv"
  "${model_root}/regular/regular_2of3_leak_card.pv"
  "${model_root}/regular/regular_2of3_leak_share1.pv"
  "${model_root}/regular/regular_2of3_leak_share1_c1_offline.pv"
  "${model_root}/regular/regular_2of3_leak_two_shares.pv"
  "${model_root}/regular/regular_2of3_no_pop_or_binding.pv"
  "${model_root}/regular/regular_token_one_time_consumption.pv"
  "${model_root}/reshare/post_reshare_e1_issuance.pv"
  "${model_root}/reshare/reshare_2to3_baseline.pv"
  "${model_root}/reshare/reshare_2to3_leak_share1.pv"
  "${model_root}/reshare/reshare_historical_share_accumulation.pv"
  "${model_root}/reshare/reshare_mixed_epoch_leak.pv"
  "${model_root}/reshare/reshare_threshold_crossed.pv"
  "${model_root}/threshold/threshold_3of5_sanity.pv"
  "${model_root}/threshold/threshold_micro_liveness.pv"
  "${model_root}/threshold/threshold_micro_safety.pv"
)

for model_path in "${model_paths[@]}"; do
  model_name="$(basename -- "${model_path}")"
  result_file="${output_dir}/${model_name%.pv}.out"
  args=(-lib "${lib_dir}/common_primitives.pvl")
  if [[ "${model_name}" == reshare_*.pv ||
        "${model_name}" == post_reshare_e1_issuance.pv ||
        "${model_name}" == integrated_smoke.pv ||
        "${model_name}" == emergency_containment*.pv ]]; then
    args+=(-lib "${lib_dir}/reshare_primitives.pvl")
  fi
  if [[ "${model_name}" == emergency_containment*.pv ]]; then
    args+=(-lib "${lib_dir}/emergency_containment_processes.pvl")
  fi
  if [[ "${model_name}" == threshold_3of5_sanity.pv ]]; then
    args+=(-lib "${lib_dir}/threshold_3of5_primitives.pvl")
  fi
  expected_count="${expected_result_counts[${model_name}]:-}"
  if [[ -z "${expected_count}" ]]; then
    echo "error: no raw-output result count registered for ${model_name}" >&2
    exit 1
  fi
  echo "==> ${model_name}"
  complete=0
  for attempt in 1 2 3; do
    "${proverif_bin}" "${args[@]}" "${model_path}" >"${result_file}" 2>&1
    result_count="$(grep -c '^RESULT ' "${result_file}" || true)"
    if [[ "${result_count}" -eq "${expected_count}" ]]; then
      complete=1
      break
    fi
    echo "warning: retrying ${model_name}; attempt ${attempt} captured ${result_count}/${expected_count} RESULT lines" >&2
  done
  if [[ "${complete}" -ne 1 ]]; then
    echo "error: incomplete raw output for ${model_name}: ${result_count}/${expected_count} RESULT lines" >&2
    tail -40 "${result_file}" >&2
    exit 1
  fi
done

sleep 1

for model_name in "${!expected_result_counts[@]}"; do
  result_file="${output_dir}/${model_name%.pv}.out"
  result_count="$(grep -c '^RESULT ' "${result_file}" || true)"
  expected_count="${expected_result_counts[${model_name}]}"
  if [[ "${result_count}" -ne "${expected_count}" ]]; then
    echo "warning: final validation retry for ${model_name}; found ${result_count}/${expected_count} RESULT lines" >&2
    model_path=""
    for candidate_path in "${model_paths[@]}"; do
      if [[ "$(basename -- "${candidate_path}")" == "${model_name}" ]]; then
        model_path="${candidate_path}"
        break
      fi
    done
    if [[ -z "${model_path}" ]]; then
      echo "error: no model path registered for ${model_name}" >&2
      exit 1
    fi
    args=(-lib "${lib_dir}/common_primitives.pvl")
    if [[ "${model_name}" == reshare_*.pv ||
          "${model_name}" == post_reshare_e1_issuance.pv ||
          "${model_name}" == integrated_smoke.pv ||
          "${model_name}" == emergency_containment*.pv ]]; then
      args+=(-lib "${lib_dir}/reshare_primitives.pvl")
    fi
    if [[ "${model_name}" == emergency_containment*.pv ]]; then
      args+=(-lib "${lib_dir}/emergency_containment_processes.pvl")
    fi
    if [[ "${model_name}" == threshold_3of5_sanity.pv ]]; then
      args+=(-lib "${lib_dir}/threshold_3of5_primitives.pvl")
    fi
    complete=0
    for attempt in 1 2 3; do
      "${proverif_bin}" "${args[@]}" "${model_path}" >"${result_file}" 2>&1
      result_count="$(grep -c '^RESULT ' "${result_file}" || true)"
      if [[ "${result_count}" -eq "${expected_count}" ]]; then
        complete=1
        break
      fi
      echo "warning: retrying ${model_name}; final attempt ${attempt} captured ${result_count}/${expected_count} RESULT lines" >&2
    done
    if [[ "${complete}" -ne 1 ]]; then
      echo "error: final raw-output validation failed for ${model_name}: ${result_count}/${expected_count} RESULT lines" >&2
      tail -40 "${result_file}" >&2
      exit 1
    fi
  fi
done

(
  cd -- "${output_dir}"
  sha256sum -- *.out >RAW_OUTPUT_MANIFEST.sha256
)

echo "PASS: raw outputs written to ${output_dir}"
