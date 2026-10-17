## Threshold Models

| File | Role | Expected interpretation |
|---|---|---|
| `models/threshold/threshold_micro_safety.pv` | Focused 2-of-3 threshold safety tests | Duplicate shares, mixed epochs/messages, wrong keys, and insufficient combinations do not yield valid threshold signatures. |
| `models/threshold/threshold_micro_liveness.pv` | Focused 2-of-3 threshold liveness tests | Each of the three valid signer pairs can produce a valid root signature under the common Chord root key. |
| `models/threshold/threshold_3of5_sanity.pv` | Bounded 3-of-5 threshold sanity check | All ten valid three-share combinations are live and representative insufficient or malformed combinations remain invalid. This is not a full 3-of-5 PGB-PKI lifecycle model. |

## Libraries

The threshold models use `lib/common_primitives.pvl`.

The 3-of-5 model additionally uses `lib/threshold_3of5_primitives.pvl`.