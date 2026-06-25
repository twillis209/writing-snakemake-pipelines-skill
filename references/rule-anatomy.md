# Rule anatomy

## Full directive set

```python
rule example:
    input:
        bam="results/aligned/{sample}.bam",
        ref="resources/genome.fa",
    output:
        vcf="results/calls/{sample}.vcf.gz",
    log:
        "logs/call_variants/{sample}.log",
    benchmark:
        "benchmarks/call_variants/{sample}.tsv"
    params:
        extra="--min-mapping-quality 20",
    threads: 4
    resources:
        mem_mb=8000,
        runtime=120,   # minutes
    conda:
        "../envs/bcftools.yaml"
    # OR container: "docker://quay.io/biocontainers/bcftools:1.19--h8b25389_0"
    wildcard_constraints:
        sample=r"[A-Za-z0-9_-]+",
    message:
        "Calling variants for {wildcards.sample}"
    shell:
        "bcftools mpileup -f {input.ref} {input.bam} 2> {log} | "
        "bcftools call -mv {params.extra} -Oz -o {output.vcf} 2>> {log}"
```

## Directive notes

### `input` / `output`
- Use named keys (`bam=`, `ref=`) — they make `shell:` strings far more readable than positional refs like `{input[0]}`.
- Wildcards in input must also appear in output (or be derivable). Wildcard names must match across input and output of the same rule.
- For dynamic input lists, prefer semantic helpers (`collect`, `lookup`, `branch`) over plain `lambda`. See `semantic-helpers.md`.

### `log`
- ALWAYS use a log. Snakemake will not stream stdout/stderr from rules to the terminal by default in cluster execution; without `log:`, you'll lose error messages.
- Wildcards in `log:` work the same as in `output:`. Pattern: `logs/<rulename>/{sample}.log`.
- Redirect both stdout and stderr in `shell:`: `... 2> {log}` or `&> {log}`.
- For `script:` rules, snakemake passes a log file handle via `snakemake.log[0]` — open it in append mode.

### `benchmark`
- One file per job, TSV format with columns: `s`, `h:m:s`, `max_rss`, `max_vms`, `max_uss`, `max_pss`, `io_in`, `io_out`, `mean_load`, `cpu_time`.
- Use it for any non-trivial rule — debugging "why is this slow" later is much easier.
- Path pattern: `benchmarks/<rulename>/{sample}.tsv`.

### `params`
- For non-file CLI flags that vary by wildcards or config.
- Access in `shell:` as `{params.extra}` (named) or `{params[0]}` (positional).
- For environment variables, route them through `params` (see `envvars:` directive) — required for reproducibility per the docs.

### `threads`
- Number of cores the job will use. `{threads}` is interpolated in `shell:`.
- **Do NOT pull `threads` from `config`.** Per the official best practices: runtime values like threads go via `--set-threads rulename=N` on the CLI or in a profile.

### `resources`
- Free-form key=value (`mem_mb=`, `runtime=`, `disk_mb=`, `tmpdir=`, custom keys).
- `mem_mb` and `runtime` (minutes) are standard for cluster executor plugins.
- Override on CLI: `--set-resources rule=mem_mb=16000`.
- Defaults via `--set-default-resources mem_mb=4000 runtime=60` or in the profile.

### `conda` vs `container`
- `conda:` path is **relative to the Snakefile that contains the rule**. For a rule in `workflow/rules/foo.smk`, write `"../envs/foo.yaml"`.
- `container:` should be a tagged image, not `latest`. Prefer `docker://` URIs (works under both Docker and Apptainer).
- Both can coexist globally and per-rule (see `deployment.md`).

### `wildcard_constraints`
- Use a raw string (`r"..."`) to avoid escaping backslashes.
- Constrain wildcards to prevent ambiguous matches. Example: `sample=r"[A-Za-z0-9_-]+"` keeps `.` from being matched and prevents conflation with extensions.
- Can also be set globally at the top of the Snakefile.

### `shell` vs `script` vs `notebook` vs `wrapper` vs `run`

| Directive | Use |
|-----------|-----|
| `wrapper:` | A snakemake-wrappers entry exists — always prefer. Pin to a tag like `"v3.4.0/bio/samtools/sort"`. |
| `shell:` | Single short CLI invocation. |
| `script:` | Non-trivial logic. Script file (any language) gets a `snakemake` object with `input`, `output`, `params`, `wildcards`, `log`, `threads`, `resources`, `config`. |
| `notebook:` | Jupyter notebook. Same conventions as `script:`. Conda env MUST include `jupyter`. |
| `run:` | **Avoid for anything non-trivial.** Runs inside the snakemake process — can't use `conda:` for non-shell calls, can't isolate. |

## Wildcards

- `{wildcard}` is captured by `.+` by default.
- Constrain with `wildcard_constraints` or inline syntax `{wildcard,REGEX}` in paths.
- Access in input/output/log/params strings; in functions as `wildcards.foo`; in `shell:` as `{wildcards.foo}`.

## Path variables (`pathvars`, v9.12+)

Recurring path components (`results`, `logs`, `temp`, …) can be written as `<placeholder>` angle-bracket vars in `input`/`output`/`log`/`benchmark` and resolved at parse time. This is the **sanctioned** way to keep path roots configurable without the `outdir`-concatenation anti-pattern (see non-negotiable #9):

```python
rule somerule:
    input:
        "<results>/something/{sample}.txt",
    output:
        "<results>/processed/{sample}.txt",
    shell:
        "somecommand {input} {output}"
```

- Built-in defaults: `results`, `stats`, `reports`, `temp`, `resources`, `logs`, `benchmarks` — each resolves to its own name (so `<results>` → `results`) unless redefined.
- Define/override globally, via config (`pathvars:` key), per-`module`, or per-rule (`pathvars` keyword), in that precedence order. Values may even contain wildcards:
  ```python
  pathvars:
      per="{sample}"
  ```
- Resolved before wildcard resolution and DAG construction.

Use this only when a path root genuinely needs to vary (e.g. a module reused in multiple contexts). For a plain single-purpose workflow, spelling out `results/...` literally is still clearest.

## Input functions (when semantic helpers aren't enough)

```python
def get_fastqs(wildcards):
    row = samples.loc[wildcards.sample]
    return {"r1": row["fq1"], "r2": row["fq2"]}


rule align:
    input:
        unpack(get_fastqs),
        ref="resources/genome.fa",
    output:
        "results/aligned/{sample}.bam",
    ...
```

Notes:
- Use a module-level `def`, not a `lambda` inside the rule (best practice from the official docs).
- Use `unpack()` for dict returns; lists are flattened automatically.
- Place all such helpers in `workflow/rules/common.smk` so rule files stay scannable.

## The default target

```python
rule all:
    input:
        collect("results/final/{sample}.txt", sample=samples.index),
    default_target: True
```

- `default_target: True` is recommended for v8+ — required when the workflow may be used as a module.
- Use `collect()` (alias for `expand()`) — it reads more clearly as "gather these per-sample outputs".
- The default target lives in the main `Snakefile`, not in included files.
