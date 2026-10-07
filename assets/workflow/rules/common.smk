import pandas as pd
from snakemake.utils import validate

validate(config, "../schemas/config.schema.yaml")


samples = (
    pd.read_table(config["samples"], dtype=str)
    .set_index("sample", drop=False)
    .sort_index()
)
validate(samples, "../schemas/samples.schema.yaml")


wildcard_constraints:
    sample=r"[A-Za-z0-9_-]+",


def get_fastqs(wildcards):
    row = samples.loc[wildcards.sample]
    out = {"r1": row["fq1"]}
    if pd.notna(row.get("fq2")):
        out["r2"] = row["fq2"]
    return out


def get_r2_arg(wildcards):
    fq2 = samples.loc[wildcards.sample, "fq2"]
    return f"--r2 {fq2}" if pd.notna(fq2) else ""
