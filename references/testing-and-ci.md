# Testing and CI

## Linting (must pass before any commit)

```bash
snakemake --lint
```

The linter checks (v9.27): rules without `log:`; rules without `conda:`/`container:`; absolute paths; path composition with `+`; shell commands using variables from outside the rule; `input[0]`/`output[0]` index access in shell; long `run:` blocks; hardcoded params that prefix an input/output; mixed rules and functions in one file (multi-file workflows only); deprecated `singularity:`; env vars not asserted via `envvars:`; tab indentation. It does **not** flag lambdas — avoiding them is best-practice guidance (non-negotiable #7), checked by review, not tooling. Per the official guidance: "highly recommended to run the linter before publishing any workflow."

`--lint` exits 1 on any lint, so a CI step fails on any warning by itself. Known false positive: the absolute-path lint matches any quoted string starting with `/`, including fragments like `outdir + "/sorted/{sample}.bam"` — fix the concatenation (which the `+` lint also flags), not a nonexistent absolute path.

## Formatting

```bash
snakefmt workflow/         # format in place
snakefmt --check workflow/ # CI mode — fail on diff
```

[snakefmt](https://github.com/snakemake/snakefmt) is to snakemake what black is to Python. Required for published workflows. snakefmt has no GitHub Action; in CI run it via `pipx run snakefmt==2.0.3 --check workflow/` (pin the version — formatting changes between releases).

## Dry-run

```bash
snakemake -n                                # dry-run with main config
snakemake -n --directory .tests/integration  # dry-run against the test data
```

Prefer `--directory` over `--configfile .tests/integration/config/config.yaml`: relative input paths (and `configfile:`) resolve against the working directory, so `--configfile` alone still looks for the test data under the repo root. A failing dry-run means missing inputs, ambiguous rules, or broken wildcard logic — fix before running for real. Since v9.27, `-n --executor <name>` validates against that executor plugin rather than the local one.

## Integration test (small dummy data)

Standard layout: `.tests/integration/`:
```
.tests/integration/
├── config/
│   └── config.yaml         # tiny dataset paths
├── data/                   # small dummy inputs (kept in git)
└── expected/               # expected outputs (optional)
```

Run:
```bash
snakemake --sdm conda --cores 1 --directory .tests/integration
```

## Auto-generated unit tests

Run the integration test with `--notemp` (otherwise `temp()` intermediates are gone and rules consuming them get no test), then generate from the same directory:
```bash
snakemake --sdm conda --cores 1 --directory .tests/integration --notemp
snakemake --directory .tests/integration --generate-unit-tests "$PWD/.tests/unit"
```

The target must be an absolute path inside the project (a relative one lands under `.tests/integration/`). This creates `.tests/unit/test_<rule>.py` for each rule whose inputs exist, copying one representative input set and producing a pytest test that:
1. Reruns just that rule on the copied inputs.
2. Compares outputs byte-by-byte (using `cmp`, `zcmp`, `bzcmp`, `xzcmp` based on extension). Since v9.27 a failure includes the comparison tool's output.

Run from the repo root (the generated tests use repo-relative `--snakefile`/`--configfile`):
```bash
pytest .tests/unit/
```

Re-running `--generate-unit-tests` **overwrites `common.py`** and skips rules that already have a `test_<rule>.py` (delete one to regenerate it). So don't edit `common.py`; customise comparison per test (v9.17+) in `test_<rule>.py`, extending rather than replacing the defaults:
```python
common.OutputChecker(data_path, expected_path, workdir).check(
    cmp_cmds={**common.cmp_cmds, ".bam": ["gatk", "CompareSAMs", "--LENIENT_HEADER"]}
)
```

Important: don't generate tests from big data — keep them under a few seconds each. Use small dummy inputs.

## GitHub Actions

- [snakemake/snakemake-github-action](https://github.com/snakemake/snakemake-github-action) — runs lint and the test workflow.
- snakefmt — a plain `run:` step (`pipx run snakefmt==2.0.3 --check workflow/`); there is no snakefmt action.

A minimal `.github/workflows/main.yml`:

```yaml
name: Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  format:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - run: pipx run snakefmt==2.0.3 --check workflow/

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: snakemake/snakemake-github-action@v2
        with:
          directory: .tests/integration
          snakefile: workflow/Snakefile
          args: "--lint"

  test:
    runs-on: ubuntu-latest
    needs: [format, lint]
    steps:
      - uses: actions/checkout@v6
      - uses: snakemake/snakemake-github-action@v2
        with:
          directory: .tests/integration
          snakefile: workflow/Snakefile
          args: "--sdm conda --cores 2 --conda-cleanup-pkgs cache"
```

The provided template asset is in `assets/.github/workflows/main.yml`.

## Reports and DAG visualization (v9)

```bash
snakemake --sdm conda --cores 1 --report-after-run --report report.html  # v9.0+: auto-build report after a successful run
snakemake --report report.html                                            # or build it separately afterwards
snakemake --dag mermaid-js > dag.mmd                                      # v9.0+: render the DAG as mermaid-js (choices: dot [default], mermaid-js)
```

`--report-after-run` requires `--report` and only fires on success — handy as a CI artifact step so each green run publishes an interactive report. Mermaid output embeds cleanly in Markdown/README without graphviz installed.

## Workflow catalog

If hosting on GitHub publicly and the repo follows the standard structure, it's auto-discovered by the [Snakemake Workflow Catalog](https://snakemake.github.io/snakemake-workflow-catalog). For the "Standardized usage" tier, fill in `.wci.yml` per the catalog rules. That gets your workflow auto-documented usage instructions.

## What you should be able to say before claiming "done"

- [ ] `snakemake --lint` exits 0 (no lints).
- [ ] `snakefmt --check workflow/` exits 0.
- [ ] `snakemake -n` resolves the DAG (and `snakemake -n --directory .tests/integration` if there's an integration test).
- [ ] If there's an integration test, it passes locally with `snakemake --sdm conda`.
- [ ] CI is green.

Detailed gates: `verification-checklist.md`.
