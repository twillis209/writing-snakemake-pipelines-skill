# v8 → v9 migration notes

Unlike v7 → v8 (which ripped executors and storage out of core into plugins), **v9 barely touches workflow authors.** Most v8 workflows run unchanged on v9. The headline v9.0 breaking change — the logging refactor and `LoggerPluginInterface` — only affects people who wrote a custom logger plugin, not Snakefiles.

This file lists the handful of things that actually changed for authors, plus the v9-only features worth adopting.

## Things to check when porting

| Area | Change | Action |
|------|--------|--------|
| Profile filename | The docs' canonical profile is now `workflow/profiles/default/profile.yaml` (was `config.yaml`). | Rename to `profile.yaml`. `config.yaml` still resolves, but `profile.yaml` avoids confusion with `config/config.yaml`. |
| Typed Python `script:` | v9.17.3 changed the syntax for type-annotating the `snakemake` object in Python scripts. | If your scripts use the typed-`snakemake` pattern, update to the new syntax; untyped scripts are unaffected. |
| Custom logging | Logging was refactored around `LoggerPluginInterface` (v9.0). | Only matters if you wrote a custom log handler/plugin. Plain workflows: nothing to do. |
| `min_version` | Bump after auditing. | `min_version("9.0")` as the baseline; bump per-feature (e.g. `min_version("9.22")` for `choose_*`). |

## Things that did NOT change

- `--sdm conda` / `--sdm apptainer` (software deployment) — same flag, same `CONDA`/`APPTAINER`/`ENV_MODULES` methods. **There is no pixi-based `--sdm`** — pixi in v9 is for packaging/dev-env only.
- The directory layout (`workflow/`, `config/`, `results/`, `resources/`).
- `rule` syntax, wrappers (still pinned by tag), conda env yaml format, JSON schemas.
- `snakefmt` and `snakemake --lint`.
- Executor and storage plugins (the v8 model is unchanged).

## v9 features worth adopting

New capabilities a ported workflow can take advantage of (none required):

- **`pathvars`** (v9.12) — `<results>/...` angle-bracket placeholders for configurable path roots. See `rule-anatomy.md`.
- **New semantic helpers** — `choose_file`/`choose_folder`/`choose_tmp` (v9.22), `as_py_module` (v9.20), `subpath(..., with_suffix=)` (v9.20), `prepend_param` (v9.21), `flatten` (v9.0). See `semantic-helpers.md`.
- **`--replace-workflow-config`** (v9.0) — make `--configfile` replace the workflow's config instead of deep-merging. See `configuration.md`.
- **Polars validation** (v9.0) — `snakemake.utils.validate()` now accepts polars `DataFrame`/`LazyFrame`, not just pandas.
- **`gh:` / `gl:` module shorthand** (v9.23) — `"gh:owner/repo@tag:workflow/Snakefile"` instead of `github(...)`. See `modularization.md`.
- **`--report-after-run`** (v9.0) and **mermaid-js `--dag`** (v9.0) — auto-build the report after a successful run and render DAGs without graphviz. See `testing-and-ci.md`.
- **`multiext` for named input/output** (v9.0), **`use rule ... with:`** selective param inheritance (v9.0), **`--omit-flags`** e.g. `--omit-flags pipe` (v9.7).

## Verification after porting

```bash
snakemake --lint
snakemake -n
snakemake --sdm conda --cores 1 --directory .tests/integration
```

If the linter is clean, the dry-run resolves, and the integration test passes, you're done.
