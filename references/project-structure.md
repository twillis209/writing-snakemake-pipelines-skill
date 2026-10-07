# Project structure

The standard layout (from `docs/snakefiles/deployment.rst`):

```
├── .gitignore
├── README.md
├── LICENSE.md
├── CODE_OF_CONDUCT.md       # if publishing
├── CONTRIBUTING.md          # if publishing
├── .tests/
│   ├── integration/         # tiny end-to-end test data + config
│   └── unit/                # per-rule tests (auto-generated)
├── images/
│   └── rulegraph.svg        # for WorkflowHub / catalog
├── workflow/
│   ├── Snakefile            # entry point
│   ├── rules/
│   │   ├── common.smk       # config loading, helpers
│   │   ├── <topic1>.smk
│   │   └── <topic2>.smk
│   ├── envs/
│   │   ├── <tool1>.yaml     # one tool per env, fine-grained
│   │   └── <tool2>.yaml
│   ├── schemas/
│   │   ├── config.schema.yaml
│   │   └── samples.schema.yaml
│   ├── scripts/
│   │   ├── script1.py
│   │   └── script2.R
│   ├── notebooks/
│   │   └── notebook1.py.ipynb
│   ├── report/
│   │   ├── workflow.rst     # workflow-level caption
│   │   └── <plot>.rst       # per-output caption
│   ├── profiles/
│   │   └── default/
│   │       └── profile.yaml # default executor + resources (name since 9.19)
│   └── documentation.md     # if publishing
├── config/
│   ├── config.yaml
│   └── samples.tsv
├── resources/               # static / downloaded reference data
└── results/                 # all workflow outputs
```

## Rules to follow

- The Snakefile is the entry point. From the project root, `snakemake -n` auto-discovers `workflow/Snakefile`.
- Rule files always end in `.smk`. Snakefmt and most editor plugins key off this extension.
- One conda env per tool, in `workflow/envs/`. Avoid mega-envs ("bioinfo.yaml" with 40 tools) — they slow solving, mask conflicts, and obscure what each rule depends on.
- Outputs go under `results/`. Reference data and other static inputs go under `resources/`.
- **Don't define a central `outdir` variable and concatenate.** Per the official docs: this "hampers readability." Spell out `results/aligned/{sample}.bam`, not `f"{outdir}/aligned/{wildcards.sample}.bam"`. To relocate outputs, run with `--directory <dir>` — it becomes the working directory, so `config/`, `resources/` and `results/` all resolve there.
- Conda envs are resolved **relative to the Snakefile that contains the rule**, so `workflow/rules/foo.smk` references `../envs/foo.yaml`.

## Snakefile entry-point template

```python
from snakemake.utils import min_version

min_version("9.19")


configfile: "config/config.yaml"


include: "rules/common.smk"
include: "rules/<topic1>.smk"
include: "rules/<topic2>.smk"


rule all:
    default_target: True
    input:
        # final targets — typically built via collect() over samples
        collect("results/final/{sample}.txt", sample=samples.index),
```

Notes:
- `min_version` makes the workflow fail fast on older snakemake. Pin to `"9.19"` as the baseline (the `profile.yaml` workflow profile is only recognised from 9.19; older versions silently ignore it), and bump per-feature if you use newer helpers (e.g. `min_version("9.22")` for `choose_file`/`choose_folder`/`choose_tmp`).
- `default_target: True` keeps `rule all` the default target even if rules end up defined above it (e.g. via `use rule` from a module). Cheap insurance; set it.
- The `rule all` lives in the Snakefile, NOT in an included `.smk` file (per the docs: includes don't override the default target).
- Move all `import` statements and helper functions into `workflow/rules/common.smk` to keep the Snakefile scannable.

## When to deviate

- Single-script throwaway pipelines: keep one `Snakefile` at the project root, no `workflow/` directory. Note that the snakemake catalog and WorkflowHub will not accept these, so deviate consciously.
- Composed workflows (using `module`): main project still uses the standard layout; modules are referenced by github tag/URL.
