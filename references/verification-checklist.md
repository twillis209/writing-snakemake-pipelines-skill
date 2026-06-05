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

Expected: "Congratulations, your workflow is in a good condition!" or equivalent. **No warnings.** Lint warnings are technical debt — fix them, don't suppress them.

Common lint warnings and fixes:

| Warning | Fix |
|---------|-----|
| Rule X has no `log:` directive | Add `log: "logs/{rule}/{wildcards.sample}.log"` and redirect stderr in shell. |
| Rule X has no `conda:` or `container:` | Add one (see `deployment.md`). |
| Rule X uses absolute path | Replace with relative path under `resources/` or `results/`. |
| `lambda` in rule | Move to a named function in `common.smk`. Use a semantic helper if possible. |

## Gate 3: DAG resolves

```bash
snakemake -n
```

Expected: prints "Job stats" table; lists jobs that would run; no errors.

If a test config exists:
```bash
snakemake -n --configfile .tests/integration/config/config.yaml
```

Common failure modes:
- `MissingInputException` — input file pattern doesn't match any rule's output. Check wildcards.
- `AmbiguousRuleException` — two rules could produce the same output. Add `wildcard_constraints` or `ruleorder`.
- `WildcardError` — wildcard in output not in input, or undefined. Check the rule's wildcard set.

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

- **`--ignore-incomplete`**: there's a real partial-output bug — your rule isn't atomic or writes outputs before completion.
- **Deleting `.snakemake/`**: state corruption is a symptom, not a cause. Find why.
- **`--force` / `--forceall`**: hiding the fact that snakemake doesn't think reruns are needed when they are. Usually wrong input/output spec.
- **`--touch` to mark outputs as done**: only OK if you genuinely just changed metadata and the outputs are correct. Don't use as a debugger.

## Reporting completion

When all gates pass, state explicitly which gates you ran and that they passed. Don't say "everything looks good" — say "I ran `snakemake --lint` (clean), `snakemake -n` (DAG resolves to N jobs), and `pytest .tests/unit/` (X/X passing)."

If a gate is not applicable (e.g., no test data exists yet), state that explicitly: "No integration test exists yet; gates 5–6 skipped."
