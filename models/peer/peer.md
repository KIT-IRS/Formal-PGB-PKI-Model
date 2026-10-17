## Peer Authentication Model

| File | Role | Expected interpretation |
|---|---|---|
| `models/peer/peer_authentication.pv` | Post-lock peer authentication | Regular and emergency credentials support the modeled mutual-authentication flows; disclosure of one endpoint key breaks authentication of that endpoint in the expected directions only. |

## Libraries

The peer authentication model uses `lib/common_primitives.pvl`.