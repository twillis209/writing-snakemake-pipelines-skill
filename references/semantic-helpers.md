# Semantic helpers

Per the official best practices: prefer these over `lambda` and bespoke Python aggregation. They make rules read like statements about intent.

## `collect` (alias for `expand`)

Use `collect()` when the rule's job is to gather a per-wildcard family of files. It reads better than `expand()` even though they're identical:

```python
rule aggregate:
    input:
        collect("results/per_sample/{sample}.txt", sample=samples.index),
    output:
        "results/aggregated.txt",
    shell:
        "cat {input} > {output}"
```

- Mask wildcards to keep them: `collect("{{dataset}}/a.{ext}", ext=FORMATS)`.
- Pair with `zip`: `collect("{a}.{b}", zip, a=AS, b=BS)`.
- Pair with `lookup()` for query-driven aggregation:
  ```python
  collect("results/{item.sample}.txt", item=lookup(query="someval > 2", within=samples))
  ```

## `lookup`

Looks up a value in a dict or pandas DataFrame/Series, with wildcard substitution.

```python
# from a config dict via dpath
lookup(dpath="tools/sometool", within=config)

# from a samples DataFrame via pandas query
lookup(query="sample == '{sample}'", within=samples, cols="fq1")

# constrain to specific columns
lookup(query="condition == 'treated'", within=samples, cols=["sample", "fq1"])

# use the result as a condition for branch()
branch(lookup(query="sample == '{sample}' & batch == 'A'", within=samples),
       then="results/foo/{sample}.txt",
       otherwise="results/bar/{sample}.txt")
```

Key signature parts:
- `within=`: dict, DataFrame, or Series (required).
- `dpath=` for dicts, `query=` for DataFrames. Since 9.25 the first positional argument is interpreted as query or dpath depending on the type of `within` (upstream docs use `lookup("sample == '{sample}'", within=samples)`); positional DataFrame queries need `min_version("9.25")` — older versions fail at parse time with "Dpath parameter can only be used with python mapping".
- `cols=`: list or single column name to constrain the result.
- `default=`: fallback if not found (else raises `LookupError` for dpath / returns `[]` for query).
- `is_nrows=N`: returns a bool — true if the query matches exactly N rows.

Wildcards in `query`/`dpath`/`cols` (e.g. `'{sample}'`) cause `lookup` to return an input function that's evaluated when wildcards are known.

## `branch`

Choose input/output/params based on a condition.

```python
# two-way
branch(
    condition=lookup(dpath="tools/use_sometool", within=config),
    then="results/sometool/{dataset}.txt",
    otherwise="results/someresult/{dataset}.txt",
)

# multi-way
branch(
    condition=lookup(dpath="tool/to/use", within=config),
    cases={
        "sometool":       "results/sometool/{dataset}.txt",
        "someothertool":  "results/someothertool/{dataset}.txt",
    },
)
```

`condition` may be a callable taking `wildcards` — branch will produce a derived input function.
With `cases=`, a condition value missing from the mapping raises `KeyError` unless `otherwise=` is also given (combining `cases` + `otherwise` is 9.24+). `cases` + `then` raises `ValueError`.

## `evaluate`

Evaluates a Python expression with wildcards substituted as strings:

```python
input:
    branch(evaluate("{sample} == '100'"),
           then="a/{sample}.txt",
           otherwise="b/{sample}.txt"),
```

Use sparingly. A named helper function is usually clearer.

## `exists`

Checks file existence at workflow-evaluation time, with proper storage-plugin awareness:

```python
rule all:
    input:
        # only expect this output if test.txt is around before the run
        "out.txt" if exists("test.txt") else [],
```

Also used as condition for `before_update` semantics — see the `update` flag.

## `parse_input`

Returns a params function that opens the input file and runs `parser(fh, **kwargs)` on it (`parser=None` → stripped file contents). It runs when the job's params are evaluated, so the input must already exist (an upstream job's output is fine):

```python
rule a:
    input:
        samples="samples.tsv",
    output:
        "samples.id",
    params:
        id=parse_input(input.samples, parser=extract_id),
    shell:
        "echo {params.id} > {output}"
```

## `extract_checksum`

A parser for `parse_input` (not standalone): reads an `md5sum`-style file and returns the checksum for `file=`. Needs pandas:

```python
params:
    checksum=parse_input(input.checksum, parser=extract_checksum, file="results/data.tsv"),
```

Pass `file=` as a plain string: kwargs go to the parser verbatim, so upstream's `file=output.tsv` fails in 9.27 (`'function' object has no attribute 'removeprefix'`).

## `prepend_param`

For tools that want a flag before each filename (e.g., `--input a.txt --input b.txt`):

```python
input:
    data=["a.txt", "b.txt", "c.txt"],
params:
    data=prepend_param("--input", input.data),
shell:
    "somecommand {params.data}"
```

## `choose_file` / `choose_folder` / `choose_tmp`

Pick the first usable path from a list, based on permissions. Added in v9.22.

```yaml
# workflow/profiles/default/profile.yaml (profile YAML, not a Snakefile directive)
default-resources:
  tmpdir: choose_tmp(["/scratch/nvme", "/home/$USER/scratch", "/scratch/$SLURM_JOB_ID"])
```

Signatures (all check by permission flags; `None` = don't care):
- `choose_file(file_list, read=True, write=True, execute=None, creatable=None)` — returns `None` if nothing matches.
- `choose_folder(folder_list, read=True, write=True, open=True, creatable=None)` — returns `None` if nothing matches.
- `choose_tmp(tmp_list, read=True, write=True, open=True, creatable=True)` — returns the string `"system_tmpdir"` if nothing matches (Snakemake's own tmpdir).

Particularly useful for HPC profiles where the right tmpdir depends on which scheduler env-var is set.

## `subpath`

Derive a related path from an input/output without string surgery. Supports `basename=`, `parent=`, `ancestor=`, `strip_suffix=`, and (v9.20+) `with_suffix=`:

```python
rule sort:
    input:
        bam="results/{sample}.bam",
    output:
        bam="results/sorted/{sample}.bam",
    params:
        prefix=subpath(output.bam, strip_suffix=".bam"),   # results/sorted/{sample}
        outdir=subpath(output.bam, parent=True),           # results/sorted
    shell:
        "sometool --prefix {params.prefix} --outdir {params.outdir} {input.bam}"
```

Use it in `params:` (or `input:`) — never in `output:`, which can't take functions. For sibling outputs use `multiext("results/{sample}", ".bam", ".bam.bai")`. `with_suffix` appends (after `strip_suffix` if both given). Prefer this over hand-built `.replace()` calls.

## `as_py_module` (v9.20+)

Translates a `.py` script path into the dotted module name for `python -m`, so a script can be run as a proper module (relative imports work):

```python
rule run_tool:
    input:
        script="workflow/scripts/tool/main.py",
    params:
        module=as_py_module(),   # defaults to input.script -> workflow.scripts.tool.main
    shell:
        "python -m {params.module}"
```

Use it via `params:` (pass `input.other` for a differently named input); it can't be called inside a `shell:` string. Raises if the path doesn't translate to a valid Python module name.

## `flatten` (v9.0+)

Recursively flattens nested lists into a single list of **strings** (every item is `str()`-ed) — handy when an input function returns nested groups:

```python
input:
    flatten([get_lane_fastqs(s) for s in samples.index]),
```

## When `lambda` is OK

Almost never. The official best practices doc says "avoid `lambda` expressions inside of rules." If a helper isn't expressible as `lookup`/`branch`/`collect`/`evaluate`, write a named `def` in `workflow/rules/common.smk` and reference it by name.
