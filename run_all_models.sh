#!/usr/bin/env bash
set -euo pipefail

# Reproduce every currently committed PGB-PKI ProVerif result contract using
# one common source tree and one selected ProVerif executable.

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
proverif_bin="${PROVERIF_BIN:-proverif}"

required_files=(
  scripts/result_contract.sh
  lib/common_primitives.pvl
  lib/reshare_primitives.pvl
  lib/emergency_containment_processes.pvl
  lib/threshold_3of5_primitives.pvl
  models/threshold/threshold_micro_safety.pv
  models/threshold/threshold_micro_liveness.pv
  models/regular/regular_2of3_baseline.pv
  models/regular/regular_2of3_leak_share1.pv
  models/regular/regular_2of3_leak_share1_c1_offline.pv
  models/regular/regular_2of3_leak_two_shares.pv
  models/regular/regular_2of3_leak_card.pv
  models/regular/regular_2of3_no_pop_or_binding.pv
  models/peer/peer_authentication.pv
  models/emergency/emergency_containment.pv
  models/emergency/emergency_containment_no_class_gate.pv
  models/emergency/emergency_baseline.pv
  models/emergency/emergency_pgbi_compromised.pv
  models/regular/regular_token_one_time_consumption.pv
  models/diagnostics/candidate_wrong_pgb_misbinding.pv
  models/threshold/threshold_3of5_sanity.pv
  models/reshare/reshare_2to3_baseline.pv
  models/reshare/reshare_2to3_leak_share1.pv
  models/reshare/reshare_mixed_epoch_leak.pv
  models/reshare/reshare_historical_share_accumulation.pv
  models/reshare/post_reshare_e1_issuance.pv
  models/reshare/reshare_threshold_crossed.pv
  models/integration/integrated_smoke.pv
  scripts/run_threshold_microtests.sh
  scripts/run_regular_2of3_baseline.sh
  scripts/run_regular_2of3_leak_share1.sh
  scripts/run_regular_2of3_leak_share1_c1_offline.sh
  scripts/run_regular_2of3_leak_two_shares.sh
  scripts/run_regular_2of3_leak_card.sh
  scripts/run_regular_2of3_no_pop_or_binding.sh
  scripts/run_peer_authentication.sh
  scripts/run_emergency_containment.sh
  scripts/run_emergency_containment_no_class_gate.sh
  scripts/run_emergency_baseline.sh
  scripts/run_emergency_pgbi_compromised.sh
  scripts/run_regular_token_one_time_consumption.sh
  scripts/run_candidate_wrong_pgb_misbinding.sh
  scripts/run_threshold_3of5_sanity.sh
  scripts/run_reshare_2to3_baseline.sh
  scripts/run_reshare_2to3_leak_share1.sh
  scripts/run_reshare_mixed_epoch_leak.sh
  scripts/run_reshare_historical_share_accumulation.sh
  scripts/run_post_reshare_e1_issuance.sh
  scripts/run_reshare_threshold_crossed.sh
  scripts/run_integrated_smoke.sh
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "${repo_root}/${required_file}" ]]; then
    echo "error: incomplete source bundle; missing ${required_file}" >&2
    exit 1
  fi
done

export PROVERIF_BIN="${proverif_bin}"

run_model() {
  local runner="$1" runner_status
  echo "==> ${runner}"
  if bash "${repo_root}/scripts/${runner}"; then
    return 0
  else
    runner_status=$?
    echo "error: ${runner} failed (exit ${runner_status}); suite stopped." >&2
    exit "${runner_status}"
  fi
}

run_model "run_threshold_microtests.sh"
run_model "run_regular_2of3_baseline.sh"
run_model "run_regular_2of3_leak_share1.sh"
run_model "run_regular_2of3_leak_share1_c1_offline.sh"
run_model "run_regular_2of3_leak_two_shares.sh"
run_model "run_regular_2of3_leak_card.sh"
run_model "run_regular_2of3_no_pop_or_binding.sh"
run_model "run_peer_authentication.sh"
run_model "run_emergency_containment.sh"
run_model "run_emergency_containment_no_class_gate.sh"
run_model "run_emergency_baseline.sh"
run_model "run_emergency_pgbi_compromised.sh"
run_model "run_regular_token_one_time_consumption.sh"
run_model "run_candidate_wrong_pgb_misbinding.sh"
run_model "run_threshold_3of5_sanity.sh"
run_model "run_reshare_2to3_baseline.sh"
run_model "run_reshare_2to3_leak_share1.sh"
run_model "run_reshare_mixed_epoch_leak.sh"
run_model "run_reshare_historical_share_accumulation.sh"
run_model "run_post_reshare_e1_issuance.sh"
run_model "run_reshare_threshold_crossed.sh"
run_model "run_integrated_smoke.sh"

echo "PASS: complete PGB-PKI ProVerif source bundle reproduced successfully."
