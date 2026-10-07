# Expected findings for the review fixture

A correct review (following `references/reviewing.md`) must surface these,
grouped by severity, each cross-referencing the named reference doc.

## Blockers (reproducibility / correctness)
- F1  — `workflow/Snakefile:align` has no `conda:` or `container:`. (deployment.md)
- F1b — `workflow/envs/samtools.yaml` pins no version for `samtools`. (deployment.md)
- F5  — `align` uses a hardcoded absolute path `/data/genomes/hg38.fa`. (project-structure.md)
- F3  — `lambda` inside `align` input. (semantic-helpers.md)

## Should-fix (fragile / non-idiomatic)
- F2  — `threads: config["threads"]`; runtime value lives in config. (rule-anatomy.md / configuration.md)
- F4  — no `validate()` of config or sample sheet. (configuration.md)
- F7  — `align` and `sort` have no `log:` directive. (rule-anatomy.md)
- F8  — central `outdir` variable + string concatenation for output paths. (project-structure.md)

## Nice-to-have (optimisation / modernisation)
- F6  — intermediate aligned BAM is never marked `temp()`. (rule-anatomy.md)
- F6b — hand-rolled `samtools sort` where a wrapper exists. (modularization.md)
- F9  — `min_version("7.0")` is stale; bump toward v9. (v8-to-v9-migration.md)
- F10 — `sort` derives the BAI path via `.replace(".bam", ".bam.bai")`; in `output:` use `multiext("results/sorted/{sample}", ".bam", ".bam.bai")` or a literal string (not `subpath` — outputs can't be functions). (semantic-helpers.md)

Total: 4 blockers, 4 should-fix, 4 nice-to-have.

## Tooling corroboration (v9.27.0)

`snakemake --lint` (exit 1) reports: 7 absolute-path lints, 6 `+`
path-composition lints (F8), 2 missing-log lints (F7), 1 missing
conda/container lint (F1). Only the line-24 absolute path is F5; the other six
hit `"/sorted/..."`/`"/aligned/..."` fragments of the F8 concatenation — side
effects of F8, not separate findings. F3 (lambda) is not lint-visible, nor are
F1b, F2, F4, F6, F6b, F9, F10.

`snakemake -n` stops with `MissingInputException` on `/data/genomes/hg38.fa`
(F5). `config/samples.tsv` and `data/A.fastq.gz` are stubs that exist only so
the tooling runs.
