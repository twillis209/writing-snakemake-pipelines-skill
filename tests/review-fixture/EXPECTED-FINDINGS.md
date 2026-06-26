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
- F10 — `sort` derives the BAI path via `.replace(".bam", ".bam.bai")`; use `subpath`. (semantic-helpers.md)

Total: 4 blockers, 4 should-fix, 4 nice-to-have.
