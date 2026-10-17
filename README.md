# Formal PGB-PKI Model

This repository contains the ProVerif models accompanying the paper “Symbolic Verification of a Decentralized Threshold PKI for Modular Automation.” 

The models analyze selected security properties of the PGB-PKI, a decentralized and threshold-protected PKI for certificate management inside a Production Gray Box (PGB).

> M. Madsen, M. Vater, and M. Barth, **"PGB-PKI: A Module-Internal Decentralized PKI for Modular Automation,"** 31st IEEE International Conference on Emerging Technologies and Factory Automation (ETFA 2026).

A current publication listing is available at the [Repository KITopen](https://publikationen.bibliothek.kit.edu/1000194199).

## Requirements

- **ProVerif 2.05**
- a **Bash-compatible shell** for the supplied regression scripts

[Download ProVerif from the ProVerif website.](https://bblanche.gitlabpages.inria.fr/proverif/)

## Repository Layout

```text
.
|-- lib/                     Shared ProVerif libraries
|-- models/
|   |-- diagnostics/         Focused diagnostic models
|   |-- emergency/           Emergency-admission models
|   |-- integration/         Integrated composition smoke test
|   |-- peer/                Peer-authentication model
|   |-- regular/             Regular-admission and compromise models
|   |-- reshare/             Committee-transition and resharing models
|   `-- threshold/           Focused threshold sanity models
|-- scripts/                 Verification and result-checking scripts
|-- outputs/                 Captured ProVerif outputs
```

More detailed descriptions of the individual models are provided in their respective subdirectories.

## Quick Start

The commands below assume the shell is in the repository root.

### Run one model directly

The `.pvl` files are libraries and should be loaded with `-lib`; they are not standalone ProVerif models.
Most models require only `lib/common_primitives.pvl`. For example:

```bash
proverif \
  -lib lib/common_primitives.pvl \
  models/regular/regular_2of3_baseline.pv
```

### Run the assertion runners

Each verification scenario has a Bash assertion runner that checks the expected result polarity and result count rather than merely executing ProVerif.

All assertion runners use `scripts/result_contract.sh` to require each complete
ProVerif 2.05 `RESULT` line exactly once. Missing, duplicate, unexpected,
malformed, and inconclusive results are rejected.

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

### Captured ProVerif outputs

The repository already contains the complete raw verifier output used for
reproducibility in `outputs/`.

The helper script

```bash
bash scripts/capture_raw_results.sh
```

can be used to regenerate these outputs from the ProVerif models.
To avoid accidentally overwriting the committed reference outputs, the script only
creates its output when the outputs/ directory does not already exist.

## Interpreting ProVerif Results

ProVerif commonly prints results in forms such as:

```text
RESULT ... is true.
RESULT ... is false.
RESULT ... cannot be proved.
```
The "true" queries correspond to security goals such as secrecy and authentication. If the RESULT is true, this means that the attacker could not obtain the marker. On the other hand, the "false" queries correspond to negative controls and reachibility. This is used so that we can confirm that an intentionally created attack does indeed work or that a certain milestone is actually reachable.

## Modeling Assumptions and Limitations

The most important interpretation boundaries are:

- The public network is controlled by a Dolev-Yao attacker that may observe, replay, redirect, inject, and suppress public messages.
- Cryptographic primitives are symbolic and perfect unless compromise or a deliberately weakened model explicitly exposes the relevant secret or check.
- The main threshold primitive is a concrete 2-of-3 abstraction with distinct, epoch-bound shares. Distributed Key Generation and the cryptographic internals of resharing are idealized rather than verified as concrete threshold-cryptography implementations.
- The PGB-PKI bootstrapping phase relies on the secure/isolated commissioning assumption where stated by the architecture.
- The verification is architecture-level. It does not prove the implementation correctness of concrete X.509, TLS/mTLS, gRPC, Chord, DKG/resharing libraries, or prototype code.
- There is no singular complete model. Instead, the PGB-PKI lifecycle is decomposed into focused models and instantiated with a concrete and representative 2-of-3 threshold.

## References

- M. Madsen, M. Vater, and M. Barth, **"PGB-PKI: A Module-Internal Decentralized PKI for Modular Automation,"** ETFA 2026. [Repository KITopen](https://publikationen.bibliothek.kit.edu/1000194199)
- B. Blanchet et al., **ProVerif 2.05**. [Official website](https://bblanche.gitlabpages.inria.fr/proverif/)
