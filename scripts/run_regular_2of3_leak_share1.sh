#!/usr/bin/env bash
set -euo pipefail

# Run the PGB-PKI regular 2-of-3 one-share-compromise model and assert its
# complete result contract. Override PROVERIF_BIN if needed.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
source "${script_dir}/result_contract.sh"
model_dir="${repo_root}/models/regular"
lib_dir="${repo_root}/lib"
proverif_bin="${PROVERIF_BIN:-proverif}"

if ! command -v "${proverif_bin}" >/dev/null 2>&1; then
  echo "error: ProVerif executable not found: ${proverif_bin}" >&2
  echo "install ProVerif 2.05+ or set PROVERIF_BIN=/path/to/proverif" >&2
  exit 127
fi

temp_parent="${TMPDIR:-${model_dir}}"
result_dir="$(mktemp -d "${temp_parent%/}/pgb-pki-leak-share1.XXXXXX")"
trap 'rm -rf -- "${result_dir}"' EXIT
result_file="${result_dir}/regular_2of3_leak_share1.out"

echo "==> regular_2of3_leak_share1.pv"
if ! "${proverif_bin}" \
    -lib "${lib_dir}/common_primitives.pvl" \
    "${model_dir}/regular_2of3_leak_share1.pv" \
    >"${result_file}" 2>&1; then
  cat "${result_file}"
  echo "error: ProVerif failed while running regular_2of3_leak_share1.pv" >&2
  exit 1
fi

pgb_prepare_results "${result_file}"
grep '^RESULT ' "${result_file}" || true

fail_expectation() {
  local description="$1"
  echo "error: result contract failed for ${description}" >&2
  echo "full ProVerif output follows" >&2
  cat "${result_file}" >&2
  exit 1
}

expect_target() {
  pgb_expect_attacker "${result_file}" "$1" "$2"
}

expect_exact_result() {
  pgb_expect_result "${result_file}" "$1"
}

# P1 after COMP-C1-SHARE: every non-leaked key/share remains secret.
for target in \
  skCard skC1Device skC2Device skC3Device skO1Device skDregDevice \
  'share2(e0)' 'share3(e0)'; do
  expect_target "${target}" true
done

# False is intentional: direct attacker knowledge confirms the copied share.
expect_target 'share1(e0)' false

# T1, setup boundary, fresh signer PoP, and guarded honest partials.
expect_exact_result \
  'event(RegularMembershipAuthorized(G,D,PK,T,S,NJ)) ==> event(CardAuthorized(pgbA,D,PK,T)) is true.'
expect_exact_result \
  'event(RegularMembershipAuthorized(G,D,PK,T,S,NJ)) ==> event(PGBLocked(pgbA)) is true.'
expect_exact_result \
  'inj-event(SignerValidated(Ci,D,PK,T,S,E,N)) ==> inj-event(RegularSignerPoPVerified(Ci,D,PK,S,E,N)) is true.'
expect_exact_result \
  'inj-event(SignerValidated(Ci,D,PK,T,S,E,N)) ==> inj-event(RegularPoPProduced(D,PK,Ci,S,N)) is true.'
expect_exact_result \
  'event(SignerValidated(Ci,D,PK,T,S,E,N)) ==> event(CardAuthorized(pgbA,D,PK,T)) is true.'
expect_exact_result \
  'event(PartialIssued(Ci,D,PK,S,E)) ==> event(SignerValidated(Ci,D,PK,T,S,E,N)) is true.'

# T3 under C1-share compromise: every final pair still contains the required
# independently validating honest shareholder.
expect_exact_result \
  'event(RegularCredentialAccepted12(G,D,PK,T,S,NJ)) ==> event(SignerValidated(C2,D,PK,T,S,e0,N2)) is true.'
expect_exact_result \
  'event(RegularCredentialAccepted13(G,D,PK,T,S,NJ)) ==> event(SignerValidated(C3,D,PK,T,S,e0,N3)) is true.'
expect_exact_result \
  'event(RegularCredentialAccepted23(G,D,PK,T,S,NJ)) ==> event(SignerValidated(C2,D,PK,T,S,e0,N2)) && event(SignerValidated(C3,D,PK,T,S,e0,N3)) is true.'

# Structural nonreachability: no share-activation service is instantiated.
expect_exact_result 'not event(ShareActivated(O1,E,pkChord,S)) is true.'
expect_exact_result 'not event(ShareActivated(Dreg,E,pkChord,S)) is true.'

# False is intentional: compromise and all honest success milestones occur.
for target in \
  reachSetup reachShare1Leak reachRepresentativeOverlayForwarding \
  reachPair12MembershipAuthorized reachPair13MembershipAuthorized reachPair23MembershipAuthorized; do
  expect_target "${target}" false
done

result_count="$(grep -c '^RESULT ' "${result_file}" || true)"
if [[ "${result_count}" -ne 26 ]]; then
  fail_expectation "exactly 26 results (found ${result_count})"
fi

if grep -Eq '(^|[[:space:]])(Warning|Error):' "${result_file}"; then
  fail_expectation "warning-free and error-free execution"
fi

pgb_assert_complete "${result_file}"

echo "PASS: all 19 security/invariant and 7 compromise/reachability expectations matched."
