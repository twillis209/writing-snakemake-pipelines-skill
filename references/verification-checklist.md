# Verification checklist

**Before claiming the workflow is correct, complete, or "done", you must have run each command in this checklist and seen the output yourself.** Do not infer success; verify it.

## Gate 1: Formatting

```bash
snakefmt --check workflow/
```

Expected: exit 0, no output. If it suggests changes, run `snakefmt workflow/` and commit.

## Gate 2: Linting

```bash
snakemake --lint
```

Expected: exit 0, "Congratulations, your workflow is in a good condition!". `--lint` exits 1 on any lint. Lint warnings are technical debt — fix them, don't suppress them. (Absolute-path hits on concatenated fragments like `outdir + "/x/{s}.bam"` are false positives; fixing the `+` composition clears both.)

Common lint warnings and fixes:

| Warning | Fix |
|---------|-----|
| No log directive defined | Add e.g. `log: "logs/align/{sample}.log"` (same wildcards as the outputs) and redirect stderr in shell. |
| Specify a conda environment or container for each rule | Add one (see `deployment.md`). |
| Absolute path "…" | Replace with relative path under `resources/` or `results/`, or make it configurable. |
| Path composition with '+' | Write the path out (`"results/sorted/{sample}.bam"`); relocate the root with `--directory`. |
| Shell command directly uses variable … from outside of the rule | Pass it through `params:`. |
| Deprecated singularity directive | Rename to `container:`. |

The linter does not check for lambdas — that's review-time guidance (`semantic-helpers.md`).

## Gate 3: DAG resolves

```bash
snakemake -n
```

Expected: prints "Job stats" table; lists jobs that would run; no errors.

If an integration test exists (runs against its own config and data):
```bash
snakemake -n --directory .tests/integration
```

For cluster/cloud runs, dry-run with the target executor (`snakemake -n --executor slurm`): since v9.27 this validates against that executor plugin.

Common failure modes:
- `MissingInputException` — input file pattern doesn't match any rule's output. Check wildcards.
- `AmbiguousRuleException` — two rules could produce the same output. Add `wildcard_constraints` or `ruleorder`.
- `WildcardError` — a wildcard in `input:` that can't be determined from the output patterns. Every wildcard used in input/log/benchmark must appear in the outputs.

## Gate 4: Conda envs solve (if `--sdm conda` used)

```bash
snakemake --sdm conda --conda-create-envs-only
```

Expected: each env yaml resolves; no version-conflict messages. This is slow on first run; subsequent runs are cached.

## Gate 5: Integration test (if present)

```bash
snakemake --sdm conda --cores 1 --directory .tests/integration
```

Expected: all jobs complete; outputs match expected; exit 0.

## Gate 6: Unit tests (if generated)

```bash
pytest .tests/unit/
```

Expected: all tests pass.

## Gate 7: CI is green

If the workflow is hosted on GitHub:

```bash
gh run list --limit 1
```

The latest run on the current branch should be `success`.

## When something fails

Don't bypass. The failure modes that "force" workarounds usually mean:

- **`--ignore-incomplete`**: incomplete outputs come from interrupted/failed jobs. Rerun them with `--rerun-incomplete` instead; if it keeps happening, the rule isn't atomic. To debug a failure, `--keep-incomplete` keeps the partial outputs (and the shadow dir of a failed `shadow:` job); clear stale shadow dirs with `--cleanup-shadow`.
- **Deleting `.snakemake/`**: state corruption is a symptom, not a cause. Find why.
- **`--force` / `--forceall`**: hiding the fact that snakemake doesn't think reruns are needed when they are. Usually wrong input/output spec.
- **`--touch` to mark outputs as done**: only OK if you genuinely just changed metadata and the outputs are correct. Don't use as a debugger.

## Reporting completion

When all gates pass, state explicitly which gates you ran and that they passed. Don't say "everything looks good" — say "I ran `snakemake --lint` (clean), `snakemake -n` (DAG resolves to N jobs), and `pytest .tests/unit/` (X/X passing)."

If a gate is not applicable (e.g., no test data exists yet), state that explicitly: "No integration test exists yet; gates 5–6 skipped."
