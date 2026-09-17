# PGB-PKI ProVerif Formal Verification

This repository contains the ProVerif models accompanying the formal verification of selected security properties of the PGB-PKI architecture. The architecture itself is described in:

> M. Madsen, M. Vater, and M. Barth, **"PGB-PKI: A Module-Internal Decentralized PKI for Modular Automation,"** 31st IEEE International Conference on Emerging Technologies and Factory Automation (ETFA 2026).

A current publication listing is available at the [Repository KITopen](https://publikationen.bibliothek.kit.edu/1000194199).

This repository is intended as a reproducibility artifact for the formal verification. It does not repeat the architectural description from the paper or the corresponding thesis chapter; the individual ProVerif files contain additional comments explaining the modeled flows and queries.

## Verification Scope

- The main PGB-PKI verification uses a concrete **2-of-3 threshold** instantiation.
- The models use ProVerif's symbolic Dolev-Yao adversary model.
- The verified suite comprises **23 models, 22 assertion runners, and 607 queries**.
- `models/threshold/threshold_3of5_sanity.pv` is a separate, bounded **3-of-5 threshold sanity check**.
- The repository does **not** claim a formal proof for arbitrary `t`-of-`n` threshold parameters.

## Requirements

- **ProVerif 2.05**
- a **Bash-compatible shell** for the supplied `scripts/run_*.sh` regression scripts
- **OPAM / OCaml** only when installing ProVerif through OPAM

## Installing ProVerif

### Official installation sources

This repository was verified with **ProVerif 2.05**. The standard OPAM installation is:

```bash
opam update
opam install proverif.2.05
```

Verify the installation with:

```bash
opam exec -- proverif -help
```

Official references:

- [ProVerif website](https://bblanche.gitlabpages.inria.fr/proverif/)
- [ProVerif 2.05 on OPAM](https://opam.ocaml.org/packages/proverif/)
- [ProVerif 2.05 manual](https://bblanche.gitlabpages.inria.fr/proverif/manual.pdf)
- [OCaml/OPAM installation documentation](https://ocaml.org/docs/installing-ocaml)
- [OCaml on Windows](https://ocaml.org/docs/ocaml-on-windows)

> **Note on the ProVerif manual:** the ProVerif 2.05 manual remains the reference used for ProVerif syntax and semantics, but its OPAM installation subsection documents the older `opam depext` workflow. Since OPAM 2.1, system/external dependency handling has been integrated into OPAM itself. See the official [OPAM 2.1.0 release notes](https://opam.ocaml.org/blog/opam-2-1-0/) for this change.

### Tested native-Windows setup

The repository was reproduced on native 64-bit Windows with:

- OPAM **2.5.2**
- a dedicated `proverif` switch using OCaml **4.14.4**
- ProVerif **2.05**
- - **Python 3** for the result-contract regression test (tested with Python 3.14)

On that tested setup, the standard `opam install proverif.2.05` path exposed Windows-specific `lablgtk` 2.18.14 build/install issues. The complete procedure used to obtain the working installation, including the local `lablgtk` patch and PowerShell environment settings, is documented separately in:

**[docs/windows_install.md](docs/windows_install.md)**

To verify an existing Windows installation without permanently activating the switch:

```powershell
opam exec --switch=proverif -- proverif -help
```

## Repository Layout

```text
.
|-- README.md
|-- run_all_models.sh
|-- lib/                     Shared ProVerif libraries
|-- models/
|   |-- diagnostics/         Focused diagnostic models
|   |-- emergency/           Emergency-admission models
|   |-- integration/         Integrated composition smoke test
|   |-- peer/                Peer-authentication model
|   |-- regular/             Regular-admission and compromise models
|   |-- reshare/             Committee-transition and resharing models
|   `-- threshold/           Focused threshold sanity models
|-- scripts/                 Per-model runners and raw-output capture
|-- tests/                   Runner-parsing tests and synthetic fixtures
|-- outputs/                 Captured ProVerif output
`-- docs/                    Supplementary testing documentation
```

`run_all_models.sh` remains at the repository root as the main entry point. All
other shell scripts resolve the repository root from their own location, so
they can be invoked from any working directory.

## Running the Verification

The commands below assume the shell is in the repository root.

### Run one model directly

Most models require only `lib/common_primitives.pvl`. For example:

```bash
proverif \
  -lib lib/common_primitives.pvl \
  models/regular/regular_2of3_baseline.pv
```

Resharing models and `models/integration/integrated_smoke.pv` additionally require `lib/reshare_primitives.pvl`:

```bash
proverif \
  -lib lib/common_primitives.pvl \
  -lib lib/reshare_primitives.pvl \
  models/reshare/reshare_2to3_baseline.pv
```

The composed emergency-containment models require both the resharing library and their shared process library:

```bash
proverif \
  -lib lib/common_primitives.pvl \
  -lib lib/reshare_primitives.pvl \
  -lib lib/emergency_containment_processes.pvl \
  models/emergency/emergency_containment.pv
```

The bounded 3-of-5 model instead additionally requires `lib/threshold_3of5_primitives.pvl`:

```bash
proverif \
  -lib lib/common_primitives.pvl \
  -lib lib/threshold_3of5_primitives.pvl \
  models/threshold/threshold_3of5_sanity.pv
```

On PowerShell, the same commands can be run through OPAM, for example:

```powershell
opam exec -- proverif `
    -lib .\lib\common_primitives.pvl `
    .\models\regular\regular_2of3_baseline.pv
```

The `.pvl` files are libraries and should be loaded with `-lib`; they are not standalone ProVerif models.

### Run the assertion runners

Each verification scenario has a Bash assertion runner that checks the expected result polarity and result count rather than merely executing ProVerif.

All assertion runners use `scripts/result_contract.sh` to require each complete
ProVerif 2.05 `RESULT` line exactly once. Missing, duplicate, unexpected,
malformed, and inconclusive results are rejected. Final `Query` summaries cannot
satisfy an assertion. Windows CRLF and Unix LF line endings are supported;
result order is immaterial.

For example:

```bash
bash scripts/run_regular_2of3_baseline.sh
```

Run the complete regression suite with:

```bash
bash run_all_models.sh
```

A successful complete run ends with:

```text
PASS: complete PGB-PKI ProVerif source bundle reproduced successfully.
```

On Windows, the Bash runners can be executed through Git Bash. From PowerShell, one possible setup is:

```powershell
$Bash = (Get-Command bash -ErrorAction SilentlyContinue).Source

if (-not $Bash) {
    $Bash = "$env:ProgramFiles\Git\bin\bash.exe"
}

opam exec -- "$Bash" ./run_all_models.sh
```

If desired, `scripts/capture_raw_results.sh` can be used to store the complete raw ProVerif output for every model in a separate output directory.

The parser regression tests use saved outputs, explicitly synthetic fixtures,
and intentionally altered copies. They test runner parsing, not the models,
and do not constitute ProVerif verification evidence.
With Python 3 installed, run them from the repository root with any interpreter, for example:

```bash
python3 tests/test_result_contract.py
```

These tests exercise all assertion runners with LF, CRLF, and reordered results,
then check rejection of missing/replaced results with retained summaries,
duplicates, changed types/polarities, unexpected or inconclusive results,
malformed result lines, warnings, and unsuccessful verifier exits.
Depending on the setup, this can take a while.

## Model Overview

### Shared libraries

| File | Purpose |
|---|---|
| `lib/common_primitives.pvl` | Shared typed terms, credentials, proof-of-possession primitives, events, and the concrete 2-of-3 threshold-signature abstraction used throughout the main models. |
| `lib/reshare_primitives.pvl` | Additional committee-proposal, committee-vote, proof-of-possession, and recipient-bound share-delivery terms used by the resharing models. |
| `lib/emergency_containment_processes.pvl` | Shared live admission, emergency validation, committee voting, and share-delivery processes for the containment model and its credential-class negative control. |
| `lib/threshold_3of5_primitives.pvl` | Separate bounded 3-of-5 threshold abstraction containing all ten valid distinct signer triples. It is not a generic `t`-of-`n` construction. |

### Executable models

| File | Role | Expected interpretation |
|---|---|---|
| `models/threshold/threshold_micro_safety.pv` | Focused 2-of-3 threshold safety tests | Duplicate shares, mixed epochs/messages, wrong keys, and insufficient combinations do not yield valid threshold signatures. |
| `models/threshold/threshold_micro_liveness.pv` | Focused 2-of-3 threshold liveness tests | Each of the three valid signer pairs can produce a valid root signature under the common Chord root key. |
| `models/regular/regular_2of3_baseline.pv` | Main regular-admission baseline | Post-lock admission succeeds only with valid PGB-specific authorization, proof of possession, and a valid 2-of-3 threshold result. |
| `models/regular/regular_2of3_leak_share1.pv` | One copied threshold share | One leaked current-epoch share remains below threshold; unauthorized regular admission still requires an honest contribution. |
| `models/regular/regular_2of3_leak_share1_c1_offline.pv` | One copied share with C1's honest signer offline | The leaked C1 share can replace C1's partial, but C2 or C3 must still honestly validate the request. |
| `models/regular/regular_2of3_leak_two_shares.pv` | Threshold-crossing negative control | Leaking two same-epoch shares allows the attacker to complete an unauthorized regular admission as expected. |
| `models/regular/regular_2of3_leak_card.pv` | Admission-root compromise negative control | Compromise of the separate admission-token signing key allows attacker-created admission material to pass otherwise honest threshold signers. |
| `models/regular/regular_2of3_no_pop_or_binding.pv` | Deliberately defective admission diagnostic | Removing request/token binding and signer-side proof of possession makes an authentic token replayable for an unauthorized identity. |
| `models/regular/regular_token_one_time_consumption.pv` | Optional one-time-token hardening | A valid token is accepted once; a second use is rejected even when accompanied by a fresh valid proof of possession. |
| `models/diagnostics/candidate_wrong_pgb_misbinding.pv` | Two-PGB target-misbinding diagnostic | Candidate-side target misbinding is reachable, while the wrong PGB cannot validate another PGB's admission token as its own. |
| `models/peer/peer_authentication.pv` | Post-lock peer authentication | Regular and emergency credentials support the modeled mutual-authentication flows; disclosure of one endpoint key breaks authentication of that endpoint in the expected directions only. |
| `models/emergency/emergency_baseline.pv` | Restricted emergency admission baseline | Emergency acceptance follows plant validation and authorized PGB-I issuance. Regular and committee services are absent; live-service containment is tested separately below. |
| `models/emergency/emergency_pgbi_compromised.pv` | PGB-I compromise negative control | Compromise of the PGB-I key enables forged emergency credentials as expected, while one leaked threshold share remains below the regular-root threshold. |
| `models/emergency/emergency_containment.pv` | Adversarial emergency containment | Live signing, committee, and share-delivery services reject emergency-only escalation under the modeled credential-class and authorization checks, while legitimate paths remain reachable. |
| `models/emergency/emergency_containment_no_class_gate.pv` | Credential-class negative control | Accepting an emergency credential in place of regular status permits committee escalation and share acquisition. Combined with compromised C1's new share, this enables root forgery; honest regular signing remains smartcard-gated. |
| `models/reshare/reshare_2to3_baseline.pv` | Main committee-transition baseline | C3 is first admitted normally, then separately authorized for committee membership; resharing activates an e1 2-of-3 committee while preserving the Chord root public key. |
| `models/reshare/reshare_2to3_leak_share1.pv` | Resharing with one copied old-epoch share | The copied C1 share can replace C1's committee partial, but C2's honest validation remains necessary for the authorized C3 transition. |
| `models/reshare/reshare_mixed_epoch_leak.pv` | Cross-epoch compromise diagnostic | One e0 share and one e1 share cannot be combined into a valid same-epoch threshold authorization. |
| `models/reshare/reshare_historical_share_accumulation.pv` | Historical-share accumulation diagnostic | Two shares from the same retired epoch, leaked at different times, can still accumulate and authorize under the unchanged root. This exposes the modeled historical-accumulation limitation. |
| `models/reshare/post_reshare_e1_issuance.pv` | Post-transition regular issuance | After activation, the explicitly modeled honest issuance path uses e1 shares; an intentionally leaked old e0 share remains attacker-usable. |
| `models/reshare/reshare_threshold_crossed.pv` | Resharing threshold-crossing negative control | With two current-epoch shares compromised, the attacker can authorize and activate a malicious target committee as expected. |
| `models/threshold/threshold_3of5_sanity.pv` | Bounded 3-of-5 threshold sanity check | All ten valid three-share combinations are live and representative insufficient or malformed combinations remain invalid. This is not a full 3-of-5 PGB-PKI lifecycle model. |
| `models/integration/integrated_smoke.pv` | Composition smoke test | A successful lifecycle trace carries C3's original admitted certificate and serials through resharing into peer validation. Its 35 security/provenance checks and ten reachability witnesses test local composition; focused models provide the adversarial analysis. |

## Interpreting ProVerif Results

ProVerif commonly prints results in forms such as:

```text
RESULT ... is true.
RESULT ... is false.
RESULT ... cannot be proved.
```

For the ordinary security and correspondence queries in this repository, `true` means that ProVerif proved the stated property.

However, **not every `false` result is a failed verification**. Several files deliberately contain reachability canaries or negative controls.

For example, a model may contain:

```prolog
free reachSetup: bitstring [private].
...
out(net, reachSetup).
...
query attacker(reachSetup).
```

The marker is initially private and is published only after the intended protocol milestone. The attacker is therefore expected to learn it. ProVerif reports this as:

```text
RESULT not attacker_bitstring(reachSetup[]) is false.
```

Here, `false` means that the statement *"the attacker cannot obtain the marker"* is false. The protocol milestone is therefore reachable as intended.

Similarly, compromise and deliberately defective models contain expected attacks. Their `false` results document the intended security boundary rather than an unexpected failure.

For this reason, the recommended way to reproduce the verification is to use the supplied `scripts/run_*.sh` scripts. They encode the expected result polarity for each model. A `PASS:` line from the corresponding runner means that the observed ProVerif results matched the expected verification contract.

## Modeling Assumptions and Limitations

The most important interpretation boundaries are:

- The public network is controlled by a Dolev-Yao attacker that may observe, replay, redirect, inject, and suppress public messages.
- Cryptographic primitives are symbolic and perfect unless compromise or a deliberately weakened model explicitly exposes the relevant secret or check.
- The main threshold primitive is a concrete 2-of-3 abstraction with distinct, epoch-bound shares. DKG and the cryptographic internals of resharing are idealized rather than verified as concrete threshold-cryptography implementations.
- The PGB-PKI bootstrapping phase relies on the secure/isolated commissioning assumption where stated by the architecture.
- Chord routing is not treated as a security boundary. The models do not verify Chord lookup correctness, stabilization, routing availability, eclipse resistance, or Sybil resistance during open bootstrapping.
- Emergency containment depends on explicit credential-class checks, trusted certification suitability, and ideal share delivery. These model enforcement choices for requirements that the paper leaves partly unspecified.
- The verification is architecture-level. It does not prove the implementation correctness of concrete X.509, TLS/mTLS, gRPC, Chord, DKG/resharing libraries, or prototype code.
- The bounded 3-of-5 sanity model provides a second concrete threshold instantiation only. It does not establish arbitrary `t`-of-`n` security.
- Availability, implementation vulnerabilities, and long-term lifecycle mechanisms not explicitly represented in a model are outside the corresponding formal claim.

## References

- M. Madsen, M. Vater, and M. Barth, **"PGB-PKI: A Module-Internal Decentralized PKI for Modular Automation,"** ETFA 2026. [Repository KITopen](https://publikationen.bibliothek.kit.edu/1000194199)
- B. Blanchet et al., **ProVerif 2.05**. [Official website](https://bblanche.gitlabpages.inria.fr/proverif/) · [OPAM package](https://opam.ocaml.org/packages/proverif/) · [Manual](https://bblanche.gitlabpages.inria.fr/proverif/manual.pdf)
