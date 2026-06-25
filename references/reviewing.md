# Reviewing an existing pipeline

Use this when handed a pipeline you didn't (just) write and asked to assess it
against current best practices — structure, idioms, reproducibility,
optimisation. This is a **read-only assessment that ends with an offer to
fix**: produce the findings first, then offer to apply them. Never edit before
the user says go.

This doc is the *method*. The *standards* live in the non-negotiables in
`SKILL.md` and the reference docs — cite them, don't restate them.

## The walk (outermost to innermost)

Always review in this fixed order so nothing is skipped and findings are
deterministic:

1. **Layout & structure** — standard `workflow/` + `config/` + `results/` +
   `resources/` layout? Rules in topical `.smk` files? Schemas in
   `workflow/schemas/`? Helpers isolated in `common.smk`? (see
   `project-structure.md`)
2. **Reproducibility** — does *every* non-trivial rule have `conda:` or
   `container:`, with pinned versions? Any global installs? Highest-value
   class. (see `deployment.md`)
3. **Config hygiene** — runtime values (threads/resources/outdir) leaking into
   `config.yaml`? Schema validation present? Sample sheet validated? (see
   `configuration.md`)
4. **Idioms** — `lambda` inside rules? Hand-rolled aggregation that should be
   `collect`/`lookup`/`branch`? `.replace()` path surgery that should be
   `subpath`? Missing `log:`? Non-trivial `run:` blocks? (see
   `semantic-helpers.md`, `rule-anatomy.md`)
5. **Optimisation** — intermediates that should be `temp()`; a `wrapper:` that
   exists for the tool; `pipe()`, `multiext`, better `threads`/`resources`.
   (see `rule-anatomy.md`, `modularization.md`)
6. **Modernisation** — deprecated v7/v8 patterns (`--use-conda`, `remote://`),
   profile filename, v9 helper functions, `pathvars`. (see
   `v8-to-v9-migration.md`)
7. **Tooling corroboration** — if the pipeline is runnable here, fold in
   `snakemake --lint` and `snakemake -n`; if not, say "not runnable here,
   static review only". (see `verification-checklist.md`)

## Each finding

Phrase every finding as four parts:

> **what** — **which `file:rule`** — **which best-practice** (cross-ref the
> reference doc) — **suggested fix**

## Severity

- **Blocker** — breaks reproducibility or correctness: a rule with no
  `conda:`/`container:`, unpinned versions, a `lambda` the linter fails on,
  hardcoded absolute paths.
- **Should-fix** — works but fragile or non-idiomatic: threads in config,
  missing `log:`, missing schema validation, hand-rolled aggregation, central
  `outdir` concatenation.
- **Nice-to-have** — optimisation/modernisation: `temp()` opportunities, an
  available wrapper, v9 helpers/`pathvars`, mermaid reports.

## Output

**Default — inline punch-list.** Group findings by severity, blockers first.
One line each: severity · `file:rule` · the issue · the fix · the reference
doc to consult. End with a one-line tally and the fix offer. Example:

```
Blockers
  [B] Snakefile:align — no conda/container; tool stack unpinned → add
      conda: "../envs/bwa.yaml" with pinned versions (deployment.md)
Should-fix
  [S] Snakefile:align — threads from config → move to --set-threads / profile
      (rule-anatomy.md)
Nice-to-have
  [N] Snakefile:sort — hand-rolled samtools sort → use the samtools/sort
      wrapper (modularization.md)

2 blockers, 1 should-fix, 1 nice-to-have. Want me to fix the blockers, the
top N, or all of them?
```

**Offered — written report.** For non-trivial pipelines (≈ >10 rules or >5
findings), offer to write the same findings to `<pipeline>/PIPELINE_REVIEW.md`
(or a path the user picks), with a short summary header. Offer it; don't write
it automatically.

## Fix hand-off

After the punch-list, offer to apply fixes: "fix the blockers / the top N /
all?". On a yes, apply them grouped by severity (blockers first), using the
authoring guidance in the other reference docs, then re-run the verification
gates (`verification-checklist.md`) if the pipeline is runnable. Never edit
before the user approves.

## Red flags — don't do these during a review

- Editing files before presenting findings or before the user says go.
- Restating best-practice rules here instead of citing the reference doc.
- Declaring a rule "fine" on reproducibility without checking version pinning,
  not just the presence of `conda:`.
- Claiming the DAG is healthy without having actually run `snakemake -n` (only
  claim tooling results you have run).
