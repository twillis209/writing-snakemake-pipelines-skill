# v7 → v8 migration notes

If you encounter a workflow that uses pre-v8 patterns, here's the upgrade path. v8 was a major release that pulled executor and storage out of core into plugins.

## CLI flag changes

| v7 | v8 |
|----|----|
| `--use-conda` | `--sdm conda` |
| `--use-singularity` | `--sdm apptainer` |
| `--use-conda --use-singularity` | `--sdm conda apptainer` |
| `--cluster "qsub ..."` | Install an executor plugin (e.g., `snakemake-executor-plugin-slurm`) and use `--executor slurm`. |
| `--kubernetes` | `--executor kubernetes` (via `snakemake-executor-plugin-kubernetes`). |
| `--cluster-config` | Removed. Use a profile. |
| `--cluster-status` / `--cluster-cancel` / `--cluster-sidecar` | Removed. Implemented inside executor plugins. |
| `--drmaa` | Removed. Use a SLURM/SGE executor plugin. |
| `--default-remote-provider` | Removed. Use a storage plugin (e.g., `snakemake-storage-plugin-s3`) and the `storage` directive. |
| `--google-lifesciences` | Removed. Use an executor plugin. |

Old `--use-conda` flags are not silently accepted — they're removed and will error.

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

`remote://` providers moved to plugins. Pattern:

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

Place at `workflow/profiles/default/config.yaml`, invoke with `--profile workflow/profiles/default`.

## Defaults shift

- `--printshellcmds` is now on by default; the old `-p` is unnecessary.
- `--latency-wait` default lowered; bump on NFS-backed clusters (`--latency-wait 60`).
- `--rerun-incomplete` is the default rerun behavior; old `--ri` shortcut still works.

## `lambda` warnings now lint-fail

The linter is stricter about `lambda` inside rules. Replace with `lookup`/`branch` or a named module-level function.

## `min_version` calls

If the workflow uses `min_version("7.x")` you'll need to upgrade — bump to `min_version("8.0")` after auditing for the above changes.

## Things that did NOT change

- The directory layout (`workflow/`, `config/`, `results/`, `resources/`).
- The `rule` syntax.
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
