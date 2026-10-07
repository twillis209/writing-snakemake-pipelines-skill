# Review fixture

A deliberately-flawed Snakemake workflow used to validate
`references/reviewing.md`. Every flaw is tagged `F<n>` in the source and
catalogued in `EXPECTED-FINDINGS.md`. Do NOT "fix" this workflow — its
brokenness is the point.

`config/samples.tsv` and `data/A.fastq.gz` are stubs so `snakemake --lint` and
`snakemake -n` can run from this directory; see `EXPECTED-FINDINGS.md` for
what the tooling reports.
