## Diagnostics Model

| File | Role | Expected interpretation |
|---|---|---|
| `models/diagnostics/candidate_wrong_pgb_misbinding.pv` | Two-PGB target-misbinding diagnostic | Candidate-side target misbinding is reachable, while the wrong PGB cannot validate another PGB's admission token as its own. |

## Libraries

The diagnostics model uses `lib/common_primitives.pvl`.