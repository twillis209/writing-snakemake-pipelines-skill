# Deployment: conda envs, containers, modules

## Software deployment in v8+

Activate via:

```bash
snakemake --sdm conda                # was --use-conda in v7
snakemake --sdm apptainer            # was --use-singularity in v7
snakemake --sdm conda apptainer      # both — conda inside a container
```

`--sdm` is short for `--software-deployment-method`. The old `--use-conda` / `--use-singularity` flags are removed in v8.

## Conda env files

One yaml per tool, in `workflow/envs/`:

```yaml
# workflow/envs/samtools.yaml
channels:
  - conda-forge
  - bioconda
  - nodefaults
dependencies:
  - samtools =1.19
  - htslib =1.19
```

Notes:
- Channel order matters — conda-forge first, bioconda second, `nodefaults` to exclude user defaults.
- **Pin versions** with `=major.minor` minimum, ideally `=major.minor.patch`. Unpinned envs are a portability bug.
- Avoid mega-envs ("bio-stack.yaml" with 50 packages). Fine-grained envs:
  - solve faster
  - make each rule's dependencies explicit
  - localize breakage when a single package needs upgrading

## Conda directive

Path is **relative to the Snakefile that defines the rule**:

```python
# workflow/rules/mapping.smk
rule bwa_index:
    input: "resources/genome.fa"
    output: multiext("resources/genome.fa", ".amb", ".ann", ".bwt", ".pac", ".sa")
    conda: "../envs/bwa.yaml"   # resolves to workflow/envs/bwa.yaml
    shell: "bwa index {input}"
```

Can also be a wildcard path or a callable returning a path (rare).

## Container directive

```python
rule call:
    container: "docker://quay.io/biocontainers/bcftools:1.19--h8b25389_0"
    ...
```

- Prefer tagged images, not `:latest`.
- `docker://` works under both Docker and Apptainer/Singularity.
- Global container: put `container: "docker://..."` at the top of the Snakefile to apply to all rules; override per-rule with `container: None` or another image.

## Combining conda + container (recommended for production)

```python
# At the top of Snakefile
container: "docker://continuumio/miniconda3:24.5.0"

rule call:
    conda: "../envs/bcftools.yaml"
    ...
```

Run with `snakemake --sdm conda apptainer`. Snakemake will pull the container, create the conda env inside, and run the job. This pins both the OS layer and tool versions.

## Pinning conda envs reproducibly

```bash
snakedeploy pin-conda-envs workflow/envs/*.yaml
```

Generates `<env>.<platform>.pin.txt` files (e.g., `samtools.linux-64.pin.txt`) using conda's explicit-spec format. When snakemake sees one of these next to an env yaml, it deploys from the pin file first. Commit pin files to git.

Update later with:
```bash
snakedeploy update-conda-envs workflow/envs/*.yaml
```

## Container image generation from conda envs

To distribute the workflow as one image without losing the readable per-rule conda yamls:

```bash
snakemake --containerize > Dockerfile
# or for Apptainer:
snakemake --containerize apptainer > workflow.def
```

Then use the produced image as a global `containerized:` directive:
```python
containerized: "docker://username/myworkflow:1.0.0"
```

This pre-bakes all conda envs into the image. Workflow still uses `conda:` directives, but downloads are skipped because envs already exist in `/conda-envs/<hash>/` inside the image.

## Envmodules (HPC only)

```python
rule bwa:
    conda: "../envs/bwa.yaml"
    envmodules:
        "bio/bwa/0.7.17",
        "bio/samtools/1.19",
    shell: ...
```

Run with `snakemake --use-envmodules`. Always provide a conda fallback so the workflow remains portable off the HPC.

## Global workflow dependencies

For packages used **outside** rules (e.g., `pandas` for reading the sample sheet, snakemake storage plugins):

```python
# At the very top of Snakefile, BEFORE the imports that need them
conda: "envs/global.yaml"

import pandas as pd
samples = pd.read_table(config["samples"]).set_index("sample", drop=False)
```

With `workflow/envs/global.yaml`:
```yaml
channels:
  - conda-forge
  - bioconda
  - nodefaults
dependencies:
  - pandas =2.1
  - snakemake-storage-plugin-s3 =0.2
```

Requires `--sdm conda`. Implemented via conda-inject — modifies sys.path on the fly without touching the snakemake env.

## Archive a workflow

```bash
snakemake --archive workflow-name.tar.gz
```

Bundles git-tracked code + all input files + conda packages into a self-contained tarball. Suitable for Zenodo upload + DOI.

## Choosing between conda and container

| Need | Choice |
|------|--------|
| Tool exists on bioconda | `conda:` per rule. |
| Tool is OS-sensitive (different glibc, etc.) | `container:` global + `conda:` per rule. |
| Distributing for users without conda | `--containerize` and ship the image. |
| HPC site has optimized binaries | `envmodules:` + `conda:` fallback. |
