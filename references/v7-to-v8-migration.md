# v7 → v8 migration notes

If you encounter a workflow that uses pre-v8 patterns, here's the upgrade path. v8 was a major release that pulled executor and storage out of core into plugins.

## CLI flag changes

| v7 | v8 |
|----|----|
| `--use-conda` | `--sdm conda` (old flag deprecated, still accepted) |
| `--use-singularity` | `--sdm apptainer` (old flag deprecated, still accepted) |
| `--use-conda --use-singularity` | `--sdm conda apptainer` |
| `--cluster "qsub ..."` | Prefer a dedicated executor plugin (e.g. `snakemake-executor-plugin-slurm`, `--executor slurm`); for a generic submit command, `--executor cluster-generic --cluster-generic-submit-cmd "qsub ..."`. |
| `--kubernetes` | `--executor kubernetes` (via `snakemake-executor-plugin-kubernetes`). |
| `--cluster-config` | Removed. Use a profile. |
| `--cluster-status` / `--cluster-cancel` / `--cluster-sidecar` | `--cluster-generic-status-cmd` / `--cluster-generic-cancel-cmd` / `--cluster-generic-sidecar-cmd` (cluster-generic plugin); dedicated plugins handle these internally. |
| `--drmaa` | `--executor drmaa` (`snakemake-executor-plugin-drmaa`), or a dedicated plugin such as slurm. |
| `--default-remote-provider` | Removed. Use a storage plugin (e.g., `snakemake-storage-plugin-s3`) and the `storage` directive. |
| `--google-lifesciences` | Removed. Use `--executor googlebatch`. |

`--use-conda` / `--use-singularity` (and `--use-apptainer`) still parse as deprecated legacy aliases mapped to `--sdm`; migrate anyway.

## Removed workflow syntax

v8 removed three long-deprecated elements — these now error:

| v7 | v8 |
|----|----|
| `dynamic()` outputs | `checkpoint` rules |
| `version:` directive | `conda:` / `container:` |
| `subworkflow` | `module` + `use rule` (see `modularization.md`) |

## Executor plugins

Core no longer includes SLURM/SGE/LSF/etc. Install separately:

```bash
pip install snakemake-executor-plugin-slurm
# then
snakemake --executor slurm ...
```

Common plugins:
- `snakemake-executor-plugin-slurm`
- `snakemake-executor-plugin-slurm-jobstep`
- `snakemake-executor-plugin-kubernetes`
- `snakemake-executor-plugin-cluster-generic` (for `--cluster "..."` style)

## Storage plugins

v7 remote providers (`from snakemake.remote.HTTP import RemoteProvider`, `HTTP.remote(...)`) moved to storage plugins. NCBI/EGA became wrappers (`entrez/efetch`, `ega/fetch`) instead. Pattern:

```python
# Old (v7):
# rule a:
#     input: HTTP.remote("https://example.com/data.txt")

# New (v8):
storage:
    provider="http",

rule a:
    input: storage.http("https://example.com/data.txt")
    ...
```

Common plugins:
- `snakemake-storage-plugin-http`
- `snakemake-storage-plugin-s3`
- `snakemake-storage-plugin-gcs`
- `snakemake-storage-plugin-azure`
- `snakemake-storage-plugin-fs`

## Profile format

The old `cluster.yaml` and many top-level keys are removed in favor of a single `profile config.yaml`:

```yaml
software-deployment-method:
  - conda
executor: slurm
cores: 16
jobs: 100
default-resources:
  mem_mb: 4000
  runtime: 60
  slurm_partition: standard
set-threads:
  bwa_mem: 8
```

Place at `workflow/profiles/default/profile.yaml` (filename recognised from v9.19; `config.yaml` works on all versions). It's applied automatically as the workflow profile — don't also pass it via `--profile`.

## `min_version` calls

If the workflow uses `min_version("7.x")` you'll need to upgrade — bump after auditing for the above changes — to `min_version("8.0")` at least, or straight to the v9 baseline in `v8-to-v9-migration.md`.

## Things that did NOT change

- The directory layout (`workflow/`, `config/`, `results/`, `resources/`).
- The `rule` syntax (apart from the removals above).
- Wrappers (still pinned by version tag).
- Conda env yaml format.
- JSON schemas for config validation.
- `snakefmt` and `--lint`.

## Verification after porting

```bash
snakemake --lint
snakemake -n
snakemake --sdm conda --cores 1 --directory .tests/integration
```

If linter is clean, dry-run resolves, and the integration test passes, you're done.
