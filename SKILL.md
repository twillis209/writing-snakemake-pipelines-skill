---
name: writing-snakemake-pipelines
description: Use when creating, editing, or scaffolding Snakemake workflows — Snakefiles, .smk rule files, workflow/ projects, config/schema files, conda envs per rule, or anything involving the snakemake CLI. Bioinformatics-flavored. Targets Snakemake v9.
---

# Writing Snakemake Pipelines

Snakemake v9 pipeline authoring that follows the official best practices: standard project layout, conda/container-based reproducibility, config-driven design, semantic helpers, wrappers, automatic reports, linting, and CI. (v9 is a small step from v8 for workflow authors — see `references/v8-to-v9-migration.md` for the few differences, and `references/v7-to-v8-migration.md` for older ports.)

## When to use

Trigger on any of:

- User mentions snakemake, a rule, wildcards, a Snakefile, `.smk`, conda env per rule
- Editing files matching `**/Snakefile`, `**/*.smk`, `workflow/**`, `config/config.yaml`, `workflow/schemas/*.yaml`
- Requests like "set up a snakemake project", "add a rule", "make this pipeline reproducible", "lint my snakefile"

**Skip when:** the user is only reading a Snakefile to answer a question and no edits are intended.

## The non-negotiables

These are pulled directly from the official `best_practices.rst` and are not negotiable:

1. **Lint and dry-run before claiming done.** `snakemake --lint` must report no warnings; `snakemake -n` must resolve the DAG without missing inputs. See `references/verification-checklist.md`.
2. **Use the standard project layout** (`workflow/Snakefile`, `workflow/rules/*.smk`, `workflow/envs/*.yaml`, `workflow/schemas/*.yaml`, `workflow/scripts/*`, `config/config.yaml`, `results/`, `resources/`). See `references/project-structure.md`.
3. **Every non-trivial rule gets an isolated software environment** — a `conda:` directive pointing to `workflow/envs/<tool>.yaml`, or a `container:` directive. Never install tools globally; never leave versions unpinned. See `references/deployment.md`.
4. **Config files hold metadata only** (samples, parameters, references). **Runtime-specific values (threads, memory, output folders) go via the CLI** (`--set-threads`, `--set-resources`, `--set-default-resources`, `--directory`). This is a frequent mistake.
5. **Validate config and sample sheets** with JSON schemas via `snakemake.utils.validate()`. See `references/configuration.md`.
6. **Prefer wrappers** from [snakemake-wrappers](https://snakemake-wrappers.readthedocs.io) when one exists for the tool. Pin the wrapper to a version tag.
7. **Prefer semantic helpers** (`collect`, `lookup`, `branch`, `evaluate`, `exists`, `choose_file`/`choose_folder`/`choose_tmp`) over `lambda` and bespoke aggregation. Avoid `lambda` inside rules. See `references/semantic-helpers.md`.
8. **Format with `snakefmt`.** Run `snakefmt workflow/` before publishing.
9. **No hardcoded paths in rules.** Reference data → `resources/`; outputs → `results/`. Don't concatenate against a central `outdir` variable — it hampers readability per the official guidance. If a path root genuinely must be configurable, use v9 **pathvars** (`<results>/...` placeholders), not string concatenation. See `references/rule-anatomy.md`.
10. **Use `--sdm conda` / `--sdm apptainer`** (v8+), not the deprecated `--use-conda` / `--use-singularity`. See `references/v7-to-v8-migration.md` if porting an older workflow.

## Decision flow

```
Task                                         → Load reference + asset
─────────────────────────────────────────────────────────────────────
Scaffold a brand-new workflow                → project-structure.md;
                                               copy assets/ wholesale
Add a single rule to an existing workflow    → rule-anatomy.md;
                                               assets/workflow/rules/example.smk
Add a software env for a new tool            → deployment.md;
                                               assets/workflow/envs/example.yaml
Add config keys / a sample sheet             → configuration.md;
                                               assets/workflow/schemas/*
Combine with an external workflow            → modularization.md
Set up CI / tests                            → testing-and-ci.md;
                                               assets/.github/workflows/main.yml
"It works on my machine" / portability bug   → deployment.md;
                                               verify all rules have conda/container
Port a v8 workflow                           → v8-to-v9-migration.md
Port a v7 workflow                           → v7-to-v8-migration.md,
                                               then v8-to-v9-migration.md
Before claiming the work is done             → verification-checklist.md
```

## Quick reference

### `script:` vs `shell:` vs `run:` vs `notebook:` vs `wrapper:`

| Use | When |
|-----|------|
| `wrapper:` | A snakemake-wrappers entry exists for the tool — always prefer this. Pin to a tag (`v3.x.y/bio/...`). |
| `shell:` | Single CLI invocation; one-liner or short pipeline. Use `{input}`, `{output}`, `{params}`, `{threads}`, `{resources}`, `{log}`. |
| `script:` | Non-trivial logic in Python/R/Julia/Rust/Bash. Script gets a `snakemake` object with `input`/`output`/`params`/`wildcards`/`log`/`threads`/`resources`/`config`. |
| `notebook:` | Same as `script:` but for Jupyter notebooks; great for reports and exploratory rules. |
| `run:` | **Discouraged** for non-trivial work — runs in the snakemake process, can't use `conda:` cleanly for non-shell calls, doesn't isolate. |

### File-flag directives

| Flag | Use when |
|------|----------|
| `temp("...")` | Intermediate file; deleted once all consumers have finished. |
| `protected("...")` | Final output that must not be accidentally overwritten — set read-only after creation. |
| `ancient("...")` | Input whose mtime should be ignored (don't re-trigger downstream). |
| `touch("...")` | Output is a sentinel (mtime matters, contents do not). |
| `directory("...")` | Output is a directory, not a single file. |
| `pipe("...")` | Output is a Unix pipe to the next rule (no intermediate file on disk). |

### Where things go

| Path | Contents |
|------|----------|
| `workflow/Snakefile` | Entry point. Loads config, includes rules, defines `rule all` with `default_target: True`. |
| `workflow/rules/*.smk` | Topical rule files (e.g., `mapping.smk`, `calling.smk`). Always `.smk` extension. |
| `workflow/envs/*.yaml` | One conda env per tool, fine-grained. Pin versions. |
| `workflow/schemas/*.yaml` | JSON schemas for `config.yaml` and tabular sheets. |
| `workflow/scripts/` | External scripts called via `script:`. |
| `workflow/notebooks/` | Jupyter notebooks called via `notebook:`. |
| `workflow/report/` | `.rst` caption files for `report()` outputs. |
| `workflow/profiles/default/profile.yaml` | Default profile (resources, executor settings). v9 docs use `profile.yaml`; `config.yaml` still resolves but `profile.yaml` avoids confusion with `config/config.yaml`. |
| `config/config.yaml` | Workflow configuration (metadata only — NOT threads/resources). |
| `config/samples.tsv` | Sample sheet (pandas-readable). |
| `resources/` | Static reference data (small things checked into git OK; large things downloaded by a rule). |
| `results/` | All workflow outputs. |
| `.tests/` | `integration/` and `unit/` test data. |

## Verification before claiming done

Run these and confirm clean output. Don't claim success until you've seen the output yourself:

```bash
snakefmt --check workflow/                       # formatting
snakemake --lint                                  # best-practice violations (must be clean)
snakemake -n                                      # dry-run; DAG must resolve
snakemake -n --configfile .tests/integration/config.yaml  # if test config exists
```

For published/CI workflows also:

```bash
snakemake --sdm conda --conda-create-envs-only   # provision envs
snakemake --sdm conda --cores 1 --directory .tests/integration  # actually execute the test
```

If any of these fail or warn, fix the workflow — don't paper over with `--ignore-incomplete` or by deleting `.snakemake/`. Detailed checklist in `references/verification-checklist.md`.

## References (load on demand)

| File | Load when |
|------|-----------|
| `references/project-structure.md` | Scaffolding a new project or reorganizing an existing one. |
| `references/rule-anatomy.md` | Writing or editing rules — full directive reference. |
| `references/semantic-helpers.md` | Using `collect`/`lookup`/`branch`/`evaluate`/`exists`/`choose_*`. |
| `references/deployment.md` | Adding/changing conda envs, containers, `--containerize`, envmodules. |
| `references/configuration.md` | Config files, JSON schemas, PEPs, tabular sample sheets. |
| `references/modularization.md` | Combining workflows, includes, modules, wrappers, meta-wrappers. |
| `references/testing-and-ci.md` | `--generate-unit-tests`, GitHub Actions, snakefmt CI. |
| `references/v8-to-v9-migration.md` | Porting a v8 workflow to v9 (profile filename, new helpers, what didn't change). |
| `references/v7-to-v8-migration.md` | Porting older workflows (deprecated flags, executor plugins). |
| `references/verification-checklist.md` | Full verification gate before declaring work complete. |

## Assets (copy/adapt)

| Path | Use when |
|------|----------|
| `assets/workflow/Snakefile` | Bootstrapping a new project. |
| `assets/workflow/rules/common.smk` | Helper functions, config loading, sample sheet loading. |
| `assets/workflow/rules/example.smk` | Template rule showing all the standard directives. |
| `assets/workflow/envs/example.yaml` | Template conda env (channels + pinned deps). |
| `assets/workflow/schemas/config.schema.yaml` | Template JSON schema for `config.yaml`. |
| `assets/workflow/schemas/samples.schema.yaml` | Template JSON schema for `samples.tsv` rows. |
| `assets/workflow/profiles/default/profile.yaml` | Default profile (resources, executor settings). |
| `assets/config/config.yaml` | Starter config with `samples:` pointer. |
| `assets/config/samples.tsv` | Starter sample sheet. |
| `assets/.github/workflows/main.yml` | CI: lint + dry-run + integration test. |
| `assets/.gitignore` | Sensible defaults for `.snakemake/`, `results/`, etc. |

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Putting `threads: config["threads"]` in a rule | Use `--set-threads rulename=N` from the CLI / profile. |
| `--use-conda` in CI scripts | Use `--sdm conda` (v8+). |
| `lambda wildcards: ...` inside `input:` | Replace with `lookup()`, `branch()`, or a named module-level function. |
| Unpinned `pandas` in env yaml | Pin to a version. Use `snakedeploy pin-conda-envs` to lock. |
| `outdir = "results"` + string concat | Hardcode paths in rules; `results/` is the convention. The official docs explicitly call out the outdir-concat anti-pattern. |
| Conda envs in random folders | All envs live in `workflow/envs/`. |
| Schema in `config/` | Schemas live in `workflow/schemas/` — they're workflow code, not config. |
| `import pandas` at the top of `Snakefile` | Put helper-Python imports and functions in `workflow/rules/common.smk` and `include:` it. Keeps the Snakefile scannable. |
| Forgetting `default_target: True` on `rule all` | Required for `module`-based composition to work cleanly. |
| `notebook:` without `jupyter` in the conda env | Add `jupyter` to the env yaml — required by snakemake. |
| Running long execution to "check" the workflow | Use `snakemake -n` (dry-run); it's instant. |

## Red flags — stop and reconsider

- "I'll just `pip install` this tool, doesn't need a conda env" → No. Make an env file.
- "Threads should be in the config so users can change them" → No. Use `--set-threads` / a profile.
- "I'll skip the schema, it's just for me" → No. Schemas catch the bad-input bug class for free.
- "The lint warning is fine, the workflow works" → No. Fix it. Lint warnings ARE the technical debt.
- "I'll commit `.snakemake/` so reruns are faster" → No. It's regeneratable and platform-specific.

## Authority

The non-negotiables in this skill are taken from `docs/snakefiles/best_practices.rst` in the snakemake repository. When in doubt, that file is the source of truth.
