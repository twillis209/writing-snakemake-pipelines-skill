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
- `dpath=` for dicts, `query=` for DataFrames.
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

Parses an input file at workflow-evaluation time and exposes the value as a param:

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

Specialization of `parse_input` for `<file>.md5`-style checksum files:

```python
params:
    checksum=parse_input(input.checksum, parser=extract_checksum, file=output.tsv),
```

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

```python
# pick a writable, readable folder for tmp output
default_resources:
    tmpdir: choose_tmp([
        "/scratch/nvme",
        "/home/$USER/scratch",
        "/scratch/$SLURM_JOB_ID",
    ])
```

Signatures (all check by permission flags):
- `choose_file(candidates, read=True, write=True, execute=None, creatable=None)`
- `choose_folder(candidates, read=True, write=True, open=True, creatable=None)`
- `choose_tmp(candidates, read=True, write=True, open=True, creatable=True)` — falls back to system tmpdir if none match.

Particularly useful for HPC profiles where the right tmpdir depends on which scheduler env-var is set.

## When `lambda` is OK

Almost never. The official best practices doc says "avoid `lambda` expressions inside of rules." If a helper isn't expressible as `lookup`/`branch`/`collect`/`evaluate`, write a named `def` in `workflow/rules/common.smk` and reference it by name.
