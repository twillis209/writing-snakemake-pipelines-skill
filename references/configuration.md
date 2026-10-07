# Configuration and validation

## The split

- **`config/config.yaml`** — workflow knobs the user can change: pipeline parameters, references to data sources, choices about which tools to enable. Metadata, not runtime.
- **`config/samples.tsv`** (or PEP) — per-sample metadata. Tabular.
- **`--set-threads` / `--set-resources` / profile** — runtime values (threads, mem, runtime, tmpdir). NOT in the config file.

Per the official best practices: "Use configuration for metadata and experiment information, **not for runtime specific configuration** like threads, resources and output folders."

## Loading config

In the Snakefile:
```python
configfile: "config/config.yaml"
```

The path resolves relative to the **working directory**, not the Snakefile (unlike `validate()`, `include:` and `conda:` paths, which resolve relative to the file containing them).

Access via the global `config` dict. CLI can override:
```bash
snakemake --config foo=1.5 bar=baz
snakemake --configfile config/local.yaml   # merged with declared configfile
snakemake --configfile config/local.yaml --replace-workflow-config  # v9: replace, don't merge
```

By default `--configfile` is deep-merged on top of the in-Snakefile `configfile:`/`config:` directive. Pass `--replace-workflow-config` (v9.0+) to fully replace it instead — useful when a downstream config should not inherit any defaults from the workflow.

## Validating config

```python
# workflow/rules/common.smk
from snakemake.utils import validate

validate(config, "../schemas/config.schema.yaml")
```

Run `validate()` BEFORE any rules use the config. Place validation in `common.smk` which is included first.

`validate()` accepts a config dict, a pandas DataFrame/Series, and (v9.0+) a polars `DataFrame`/`LazyFrame` — so the sample-sheet pattern below works whether you read with pandas or polars.

## Validating a sample sheet

```python
import pandas as pd
from snakemake.utils import validate

samples = pd.read_table(config["samples"], dtype=str).set_index("sample", drop=False)
validate(samples, "../schemas/samples.schema.yaml")
```

Defaults declared in the schema (`default:`) are filled in automatically.

## Schema format (JSON Schema draft 2020-12)

`workflow/schemas/config.schema.yaml`:
```yaml
$schema: "https://json-schema.org/draft/2020-12/schema"
description: workflow configuration
type: object
properties:
  samples:
    type: string
    description: path to the samples TSV
  reference:
    type: object
    properties:
      genome:
        type: string
        description: path to the reference FASTA
    required: [genome]
  params:
    type: object
    properties:
      min_mapq:
        type: integer
        default: 20
required:
  - samples
  - reference
```

`workflow/schemas/samples.schema.yaml` (per-row schema):
```yaml
$schema: "https://json-schema.org/draft/2020-12/schema"
description: a row in samples.tsv
type: object
properties:
  sample:
    type: string
    description: unique sample identifier
  condition:
    type: string
  fq1:
    type: string
    description: path to read 1
  fq2:
    type: string
    description: path to read 2 (empty for single-end)
required:
  - sample
  - condition
  - fq1
```

Default values in the schema **populate missing columns** when `validate()` runs against the DataFrame. Useful for adding new columns without breaking existing sample sheets. Don't add a redundant `paired` flag — derive single/paired-end from whether `fq2` is set (as `get_fastqs` below does). `validate()` uses a Draft 2020-12 validator; old `draft-06` `$schema` URIs fail with `UnknownDialect`.

## YTE templating

Optional templating engine for config files. Activate by setting `__use_yte__: true` at the top of the config; `__definitions__` holds Python statements whose names the `?`-prefixed expressions can use:

```yaml
__use_yte__: true

__definitions__:
  - genome_build = "GRCh38"

reference:
  genome: ?f"resources/{genome_build}.fa"
  annotation: ?f"resources/{genome_build}.gtf"
```

Useful for shared config files that need light parameterization. Don't go overboard — readability matters.

## Sample sheets via pandas

Recommended pattern for `workflow/rules/common.smk`:

```python
import pandas as pd
from snakemake.utils import validate

validate(config, "../schemas/config.schema.yaml")

samples = (
    pd.read_table(config["samples"], dtype=str)
    .set_index("sample", drop=False)
    .sort_index()
)
validate(samples, "../schemas/samples.schema.yaml")


def get_fastqs(wildcards):
    row = samples.loc[wildcards.sample]
    if pd.notna(row.get("fq2")):
        return {"r1": row["fq1"], "r2": row["fq2"]}
    return {"r1": row["fq1"]}
```

Then in rule files: `input: unpack(get_fastqs), ...`.

## PEPs

For sample sheets that need to be portable across workflows and platforms, use a [PEP](http://pep.databio.org):

```python
pepfile: "config/pep/config.yaml"
pepschema: "schemas/pep.yaml"

rule all:
    input:
        collect("{sample}.txt", sample=pep.sample_table["sample_name"]),
```

Requires `peppy` (for `pepfile:`) and `eido` (for `pepschema:`) installed alongside snakemake. PEPs are for **sample metadata only**. Pair with a regular config file for workflow-specific options.

## Environment variables

Secrets like API tokens go via env vars, not config:

```python
envvars:
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",

rule upload:
    output: "uploaded.txt"
    params:
        key=os.environ["AWS_ACCESS_KEY_ID"],
    shell: ...
```

The `envvars:` directive ensures the variables exist (fast fail) and propagates them to remote/cluster jobs. They are NOT auto-injected into the shell environment for the job — you must thread them through `params:` for reproducibility.

## Profile (default executor and resources)

`workflow/profiles/default/profile.yaml` (`profile.yaml` recognised since 9.19 — hence `min_version("9.19")` in the scaffold; `config.yaml` still resolves):
```yaml
software-deployment-method:
  - conda
cores: all
default-resources:
  mem_mb: 4000
  runtime: 60
  tmpdir: '"/tmp"'
set-threads:
  bwa_mem: 8
  samtools_sort: 4
set-resources:
  bwa_mem:
    mem_mb: 16000
    runtime: 240
```

Auto-applied when running from the project root — don't also pass `--profile workflow/profiles/default` (that loads it twice). Use `--workflow-profile none` to disable it. This is the right place for runtime config — NOT `config/config.yaml`.
