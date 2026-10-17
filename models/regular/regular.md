## Regular Admission Models

| File | Role | Expected interpretation |
|---|---|---|
| `models/regular/regular_2of3_baseline.pv` | Main regular-admission baseline | Post-lock admission succeeds only with valid PGB-specific authorization, proof of possession, and a valid 2-of-3 threshold result. |
| `models/regular/regular_2of3_leak_share1.pv` | One copied threshold share | One leaked current-epoch share remains below threshold; unauthorized regular admission still requires an honest contribution. |
| `models/regular/regular_2of3_leak_share1_c1_offline.pv` | One copied share with C1's honest signer offline | The leaked C1 share can replace C1's partial, but C2 or C3 must still honestly validate the request. |
| `models/regular/regular_2of3_leak_two_shares.pv` | Threshold-crossing negative control | Leaking two same-epoch shares allows the attacker to complete an unauthorized regular admission as expected. |
| `models/regular/regular_2of3_leak_card.pv` | Admission-root compromise negative control | Compromise of the separate admission-token signing key allows attacker-created admission material to pass otherwise honest threshold signers. |
| `models/regular/regular_2of3_no_pop_or_binding.pv` | Deliberately defective admission diagnostic | Removing request/token binding and signer-side proof of possession makes an authentic token replayable for an unauthorized identity. |
| `models/regular/regular_token_one_time_consumption.pv` | Optional one-time-token hardening | A valid token is accepted once; a second use is rejected even when accompanied by a fresh valid proof of possession. |

## Libraries

The regular admission models use only `lib/common_primitives.pvl`.