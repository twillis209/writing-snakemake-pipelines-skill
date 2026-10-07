# Modularization

Four levels of reuse, from finest to coarsest:

1. **Wrappers** — single-rule wrappers around CLI tools, from `snakemake-wrappers`.
2. **Includes** — `include: "rules/foo.smk"` inside one workflow.
3. **Modules** — `module foo: ... use rule * from foo` to compose external workflows.
4. **Meta-wrappers** — published multi-rule modules from `snakemake-wrappers`.

## Wrappers (prefer when available)

```python
rule samtools_sort:
    input:  "mapped/{sample}.bam"
    output: "mapped/{sample}.sorted.bam"
    params: "-m 4G"
    threads: 8
    wrapper: "v9.19.0/bio/samtools/sort"
```

- Pin to a release tag (`v9.19.0/...`), not a branch. Wrapper changes ship via version bumps.
- The wrapper automatically installs its conda env (under `--sdm conda`) — you do NOT need to write a separate `envs/` yaml for wrapped rules.
- Browse at [snakemake-wrappers.readthedocs.io](https://snakemake-wrappers.readthedocs.io). README per wrapper shows the required `input:`/`output:`/`params:` keys.

If you write a rule from scratch and a wrapper exists, you're duplicating effort. From the official best practices: "Make use of Snakemake wrappers whenever possible."

## Includes (within one workflow)

```python
# workflow/Snakefile
include: "rules/common.smk"
include: "rules/qc.smk"
include: "rules/mapping.smk"
include: "rules/calling.smk"
```

- Paths are relative to the file doing the include.
- The default target (`rule all`) is NOT overridden by includes — it's always the first rule in the top-level Snakefile.
- Group rules by topic (one `.smk` per pipeline stage), not by tool.

## Modules (composing external workflows)

```python
from snakemake.utils import min_version
min_version("9.19")

configfile: "config/config.yaml"

module dna_seq:
    snakefile:
        github("snakemake-workflows/dna-seq-gatk-variant-calling",
               path="workflow/Snakefile",
               tag="v2.1.1")
    config: config["dna-seq"]
    prefix: "dna-seq"     # namespaces all relative paths

use rule * from dna_seq as dna_seq_*

# Add a custom rule that uses the module's outputs
rule plot_vafs:
    input:  "dna-seq/filtered/all.vcf.gz"
    output: "results/plots/vafs.svg"
    notebook: "notebooks/plot-vafs.py.ipynb"

# Re-define the default target to include both
rule all:
    default_target: True
    input:
        rules.dna_seq_all.input,
        "results/plots/vafs.svg",
```

Key points:
- **Pin to a tag**. `tag="v2.1.1"` (or `commit=`) is reproducible and snakemake caches the fetched source persistently. `branch=` is re-fetched every run and not reproducible.
- `as dna_seq_*` prefixes the imported rule names to avoid collisions.
- `prefix: "dna-seq"` namespaces relative paths in the module — combine multiple modules without file-name clashes.
- Use `config: config["dna-seq"]` to scope the module's view of config.
- The default target must be redefined in the composing workflow.
- A global `container:` in the composing Snakefile does NOT reach module rules (scoped per module since 9.25.2) — override per rule via `use rule ... with: container: ...`.

### Modifying a rule from a module

```python
use rule bwa_mem from dna_seq as dna_seq_bwa_mem with:
    input:
        get_input,    # local function
```

`with:` overrides specified directives wholesale (except the execution step). Keyword `params` are selectively replaced; positional `params` are overwritten.

### Selective import

```python
use rule align, call from dna_seq as dna_seq_*  # only two rules
```

### Code-hosting helpers

```python
github("owner/repo", path="workflow/Snakefile", tag="v1.0.0")
gitlab("owner/repo", path="workflow/Snakefile", tag="v1.0.0")
gitlab("owner/repo", path="workflow/Snakefile", tag="v1.0.0", host="git.internal")
```

Private repos: set `GITHUB_TOKEN` or `GITLAB_TOKEN`.

**v9.23+ shorthand** — for hosted repos you can pass a single pinned string instead of `github(...)`/`gitlab(...)`:

```python
module dna_seq:
    snakefile:
        "gh:snakemake-workflows/dna-seq-gatk-variant-calling@v2.0.1:workflow/Snakefile"
        # path defaults to workflow/Snakefile, so this is equivalent:
        # "gh:snakemake-workflows/dna-seq-gatk-variant-calling@v2.0.1"
    config: config["dna-seq"]
```

`gh:` = GitHub, `gl:` = GitLab. `@tag` pins the version, but the shorthand passes the ref as a branch, so it is NOT persistently cached — the repo is re-fetched every run. Use `github(..., tag=...)` if offline runs or caching matter. Either way: pin a tag, never a branch name.

## Meta-wrappers

Pre-composed module from `snakemake-wrappers`:

```python
module bwa_mapping:
    meta_wrapper: "v9.19.0/meta/bio/bwa_mapping"

use rule * from bwa_mapping

use rule bwa_mem from bwa_mapping with:
    input: get_input
```

Browse meta-wrappers in the [snakemake-wrappers repo](https://github.com/snakemake/snakemake-wrappers/tree/main/meta).

## Snakedeploy

`snakedeploy deploy-workflow` automates module setup for end users:

```bash
snakedeploy deploy-workflow \
    https://github.com/snakemake-workflows/dna-seq-gatk-variant-calling \
    my-project \
    --tag v2.1.1
```

Generates a fresh project whose `workflow/Snakefile` references the published workflow as a module, plus a copy of its `config/` (and `profiles/` if present). Use this when consuming a published catalog workflow.

## When to factor out a module

The official best practices: contribute a wrapper or module "whenever you have a rule that reoccurs in at least two of your workflows."
