## Resharing Models

| File | Role | Expected interpretation |
|---|---|---|
| `models/reshare/reshare_2to3_baseline.pv` | Main committee-transition baseline | C3 is first admitted normally, then separately authorized for committee membership; resharing activates an e1 2-of-3 committee while preserving the Chord root public key. |
| `models/reshare/reshare_2to3_leak_share1.pv` | Resharing with one copied old-epoch share | The copied C1 share can replace C1's committee partial, but C2's honest validation remains necessary for the authorized C3 transition. |
| `models/reshare/reshare_mixed_epoch_leak.pv` | Cross-epoch compromise diagnostic | One e0 share and one e1 share cannot be combined into a valid same-epoch threshold authorization. |
| `models/reshare/reshare_historical_share_accumulation.pv` | Historical-share accumulation diagnostic | Two shares from the same retired epoch, leaked at different times, can still accumulate and authorize under the unchanged root. This exposes the modeled historical-accumulation limitation. |
| `models/reshare/post_reshare_e1_issuance.pv` | Post-transition regular issuance | After activation, the explicitly modeled honest issuance path uses e1 shares; an intentionally leaked old e0 share remains attacker-usable. |
| `models/reshare/reshare_threshold_crossed.pv` | Resharing threshold-crossing negative control | With two current-epoch shares compromised, the attacker can authorize and activate a malicious target committee as expected. |

## Libraries

The resharing models use `lib/common_primitives.pvl` and `lib/reshare_primitives.pvl`.