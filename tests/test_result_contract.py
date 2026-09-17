#!/usr/bin/env python3
"""Exercise shell runners with historical/synthetic fixtures, not a ProVerif run.

Run from any directory with a Python 3 interpreter, for example:
    python3 tests/test_result_contract.py
or on Windows:
    python tests/test_result_contract.py

Only temporary files are written. Requires Python 3 and the runners' Bash tools.
"""

import concurrent.futures
import os
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]

STUB = r'''import os
from pathlib import Path
import re
import sys

model = Path(sys.argv[-1]).stem
fixture_root = Path(os.environ["PGB_FIXTURES"])
synthetic = fixture_root.parent / "tests" / "fixtures" / (model + ".txt")
raw = (
    synthetic
    if synthetic.is_file()
    else fixture_root / (model + ".out")
).read_bytes()

mode = os.environ["PGB_MODE"]

if model != os.environ.get("PGB_TARGET", model):
    mode = "lf"

if mode == "crlf":
    sys.stdout.buffer.write(
        raw.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
    )
    sys.exit(0)

lines = raw.decode().splitlines()
indices = [i for i, line in enumerate(lines) if line.startswith("RESULT ")]
first = indices[0]
original = lines[first]

flipped = (
    original[:-len(" is true.")] + " is false."
    if original.endswith(" is true.")
    else original[:-len(" is false.")] + " is true."
)

if mode == "reordered":
    lines = [lines[i] for i in reversed(indices)]

elif mode == "missing":
    del lines[first]

elif mode == "summary_only":
    lines = [line for line in lines if not line.startswith("RESULT")]

elif mode == "replacement":
    # Keep the Query summary and result count: this bypassed the old parser.
    lines[first] = "RESULT not attacker_bitstring(unrelated[]) is true."

elif mode == "wrong_type":
    lines[first] = (
        original
        .replace("attacker_skey(", "attacker_bitstring(")
        .replace("attacker_thresholdShare(", "attacker_bitstring(")
    )
    if lines[first] == original:
        lines[first] = original.replace(
            "attacker_bitstring(",
            "attacker_skey("
        )

elif mode == "polarity":
    lines[first] = flipped

elif mode == "duplicate":
    lines.append(original)

elif mode == "duplicate_same_count":
    lines[indices[1]] = original

elif mode == "conflicting":
    lines.append(flipped)

elif mode == "unexpected":
    lines.append("RESULT not attacker_bitstring(extra[]) is true.")

elif mode == "inconclusive":
    lines[first] = re.sub(
        r" is (true|false)\.$",
        " cannot be proved.",
        original
    )

elif mode == "extra_inconclusive":
    lines.append(
        "RESULT not attacker_bitstring(extra[]) cannot be proved."
    )

elif mode == "malformed":
    lines.append("RESULT\tunrecognized result")

elif mode == "warning":
    lines.append("Warning: injected parser regression fixture")

sys.stdout.write("\n".join(lines) + "\n")
sys.exit(1 if mode == "exit_failure" else 0)
'''


def main():
    runners = sorted((ROOT / "scripts").glob("run_*.sh"))

    models_by_stem = {
        p.stem: p
        for p in (ROOT / "outputs").glob("*.out")
    }
    models_by_stem.update({
        p.stem: p
        for p in (ROOT / "tests" / "fixtures").glob("*.txt")
    })

    models = sorted(
        models_by_stem.values(),
        key=lambda p: p.stem
    )

    # Syntax-check all Bash scripts before starting the regression cases.
    for script in (
        list((ROOT / "scripts").glob("*.sh"))
        + [ROOT / "run_all_models.sh"]
    ):
        subprocess.run(
            ["bash", "-n", str(script)],
            check=True
        )

    with tempfile.TemporaryDirectory(
        prefix="pgb-parser-tests-"
    ) as temp:

        temp_path = Path(temp)

        # The actual fixture implementation is ordinary Python and contains
        # no interpreter-name assumption.
        stub_py = temp_path / "proverif_fixture.py"
        stub_py.write_text(
            STUB,
            encoding="utf-8"
        )

        # The runners expect PROVERIF_BIN to be directly executable.
        # Use the exact interpreter that launched this regression test,
        # rather than assuming it is named "python3".
        stub = temp_path / "proverif-fixture"

        python_exe = Path(sys.executable).as_posix()
        stub_py_path = stub_py.as_posix()

        stub.write_text(
            "#!/usr/bin/env bash\n"
            f'exec "{python_exe}" "{stub_py_path}" "$@"\n',
            encoding="utf-8"
        )
        stub.chmod(0o755)

        base_env = dict(
            os.environ,
            PROVERIF_BIN=str(stub),
            PGB_FIXTURES=str(ROOT / "outputs"),
            TMPDIR=temp,
        )

        cases = []

        # Valid historical output must still be accepted if line endings
        # differ or RESULT lines are reordered.
        for runner in runners:
            for mode in ("lf", "crlf", "reordered"):
                cases.append(
                    (runner, mode, "", True)
                )

        negative_modes = (
            "missing",
            "summary_only",
            "replacement",
            "wrong_type",
            "polarity",
            "duplicate",
            "duplicate_same_count",
            "conflicting",
            "unexpected",
            "inconclusive",
            "extra_inconclusive",
            "malformed",
            "warning",
            "exit_failure",
        )

        # Every stored output / synthetic fixture is mutated in ways that
        # the corresponding assertion runner is expected to reject.
        for model in models:
            runner_name = (
                "run_threshold_microtests.sh"
                if model.stem.startswith("threshold_micro_")
                else "run_" + model.stem + ".sh"
            )

            runner = ROOT / "scripts" / runner_name

            if not runner.is_file():
                raise AssertionError(
                    "Missing runner: " + str(runner)
                )

            for mode in negative_modes:
                cases.append(
                    (runner, mode, model.stem, False)
                )

        def run_case(case):
            runner, mode, target, should_pass = case

            env = dict(
                base_env,
                PGB_MODE=mode
            )

            if target:
                env["PGB_TARGET"] = target
            else:
                env.pop("PGB_TARGET", None)

            result = subprocess.run(
                ["bash", str(runner)],
                env=env,
                cwd=temp,
                capture_output=True,
                text=True,
                timeout=60,
            )

            if (result.returncode == 0) != should_pass:
                return (
                    runner.name,
                    mode,
                    target,
                    result.returncode,
                    result.stdout[-1000:],
                    result.stderr[-1000:],
                )

            return None

        print(
            f"Running {len(cases)} result-contract regression cases...",
            flush=True,
        )

        with concurrent.futures.ThreadPoolExecutor(
            max_workers=6
        ) as executor:
            failures = [
                failure
                for failure in executor.map(run_case, cases)
                if failure
            ]

        if failures:
            for failure in failures:
                print(
                    "FAIL:",
                    failure,
                    file=sys.stderr
                )
            return 1

        print(
            "Individual regression cases passed; "
            "testing aggregate runner replay...",
            flush=True,
        )

        aggregate = subprocess.run(
            ["bash", str(ROOT / "run_all_models.sh")],
            env=dict(
                base_env,
                PGB_MODE="crlf"
            ),
            cwd=temp,
            capture_output=True,
            text=True,
            timeout=120,
        )

        if aggregate.returncode:
            print(
                aggregate.stderr[-2000:],
                file=sys.stderr
            )
            return 1

        print(
            f"PASS: {len(runners)} runners; "
            f"{len(runners) * 3} valid-output cases, "
            f"{len(models) * len(negative_modes)} rejected mutations, "
            "and aggregate runner replay. No ProVerif execution."
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())