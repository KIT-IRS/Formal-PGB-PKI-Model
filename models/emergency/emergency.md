## Emergency Admission Models

| File | Role | Expected interpretation |
|---|---|---|
| `models/emergency/emergency_baseline.pv` | Restricted emergency admission baseline | Emergency acceptance follows plant validation and authorized PGB-I issuance. Regular and committee services are absent; live-service containment is tested separately below. |
| `models/emergency/emergency_pgbi_compromised.pv` | PGB-I compromise negative control | Compromise of the PGB-I key enables forged emergency credentials as expected, while one leaked threshold share remains below the regular-root threshold. |
| `models/emergency/emergency_containment.pv` | Adversarial emergency containment | Live signing, committee, and share-delivery services reject emergency-only escalation under the modeled credential-class and authorization checks, while legitimate paths remain reachable. |
| `models/emergency/emergency_containment_no_class_gate.pv` | Credential-class negative control | Accepting an emergency credential in place of regular status permits committee escalation and share acquisition. Combined with compromised C1's new share, this enables root forgery; honest regular signing remains smartcard-gated. |

## Libraries

The emergency admission models use `lib/common_primitives.pvl`.

The two containment models additionally use `lib/reshare_primitives.pvl` and `lib/emergency_containment_processes.pvl`.