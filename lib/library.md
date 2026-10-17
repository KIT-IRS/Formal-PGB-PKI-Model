## Shared ProVerif Libraries

This directory contains the reusable ProVerif definitions shared by the verification models.

The .pvl files are libraries and are not intended to be executed independently.

Individual model READMEs identify the libraries required by each model group.

| File | Purpose |
|---|---|
| `lib/common_primitives.pvl` | Shared typed terms, credentials, proof-of-possession primitives, events, and the concrete 2-of-3 threshold-signature abstraction used throughout the main models. |
| `lib/reshare_primitives.pvl` | Additional committee-proposal, committee-vote, proof-of-possession, and recipient-bound share-delivery terms used by the resharing models. |
| `lib/emergency_containment_processes.pvl` | Shared live admission, emergency validation, committee voting, and share-delivery processes for the containment model and its credential-class negative control. |
| `lib/threshold_3of5_primitives.pvl` | Separate bounded 3-of-5 threshold abstraction containing all ten valid distinct signer triples. It is not a generic `t`-of-`n` construction. |
