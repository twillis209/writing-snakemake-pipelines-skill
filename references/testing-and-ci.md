# Testing and CI

## Linting (must pass before any commit)

```bash
snakemake --lint
```

The linter flags best-practice violations: missing conda/container, hardcoded paths, lambdas in rules, missing logs, etc. Per the official guidance: "highly recommended to run the linter before publishing any workflow."

CI should run lint and fail on any warning.

## Formatting

```bash
snakefmt workflow/         # format in place
snakefmt --check workflow/ # CI mode — fail on diff
```

[snakefmt](https://github.com/snakemake/snakefmt) is to snakemake what black is to Python. Required for published workflows. There's an official GitHub Action.

## Dry-run

```bash
snakemake -n                                     # dry-run with main config
snakemake -n --configfile .tests/integration/config.yaml
```

A failing dry-run means missing inputs, ambiguous rules, or broken wildcard logic — fix before running for real.

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

After a successful integration run:
```bash
snakemake --generate-unit-tests
```

This creates `.tests/unit/test_<rule>.py` for each rule, copying one representative input set and producing a pytest test that:
1. Reruns just that rule on the copied inputs.
2. Compares outputs byte-by-byte (using `cmp`, `zcmp`, `bzcmp`, `xzcmp` based on extension).

Run with:
```bash
pytest .tests/unit/
```

Customize the comparison for specific file types via `cmp_cmds` in `common.py`:
```python
cmp_cmds = {
    ".gz":  ["zcmp"],
    ".bam": ["gatk", "CompareSAMs", "--LENIENT_HEADER"],
    ".txt": ["diff", "--ignore-matching-lines", "^#"],
}
```

Important: don't generate tests from big data — keep them under a few seconds each. Use small dummy inputs.

## GitHub Actions

Use the official actions:

- [snakemake/snakemake-github-action](https://github.com/snakemake/snakemake-github-action) — runs lint and the test workflow.
- [snakefmt's GitHub Action](https://github.com/snakemake/snakefmt#github-actions) — checks formatting.

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
      - uses: actions/checkout@v4
      - uses: snakemake/snakefmt@v0.8.5

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: snakemake/snakemake-github-action@v2
        with:
          directory: .tests/integration
          snakefile: workflow/Snakefile
          args: "--lint"

  test:
    runs-on: ubuntu-latest
    needs: [format, lint]
    steps:
      - uses: actions/checkout@v4
      - uses: snakemake/snakemake-github-action@v2
        with:
          directory: .tests/integration
          snakefile: workflow/Snakefile
          args: "--sdm conda --cores 2 --conda-cleanup-pkgs cache"
```

The provided template asset is in `assets/.github/workflows/main.yml`.

## Workflow catalog

If hosting on GitHub publicly and the repo follows the standard structure, it's auto-discovered by the [Snakemake Workflow Catalog](https://snakemake.github.io/snakemake-workflow-catalog). For the "Standardized usage" tier, fill in `.wci.yml` per the catalog rules. That gets your workflow auto-documented usage instructions.

## What you should be able to say before claiming "done"

- [ ] `snakemake --lint` exits 0 with no warnings.
- [ ] `snakefmt --check workflow/` exits 0.
- [ ] `snakemake -n` resolves the DAG (or `snakemake -n --configfile .tests/integration/config.yaml` if there's a test config).
- [ ] If there's an integration test, it passes locally with `snakemake --sdm conda`.
- [ ] CI is green.

Detailed gates: `verification-checklist.md`.
