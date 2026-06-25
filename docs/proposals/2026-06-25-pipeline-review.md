# Pipeline-review capability for `writing-snakemake-pipelines`

**Status:** Proposed, not yet enacted.
**Date:** 2026-06-25.

## Background

The skill today has two behavioural surfaces:

- **Authoring** — `SKILL.md` plus the `references/` docs guide an agent
  creating or editing a workflow.
- **Verification** — `references/verification-checklist.md` checks the agent's
  *own* just-written work by running `snakemake --lint`, a dry-run, and tests.

Neither covers a distinct third need: being handed a *pre-existing* pipeline
(possibly inherited, possibly written by someone else) and asked to evaluate
its structure, idioms, and reproducibility against current best practices, then
surface opportunities for optimisation and helper-function use.

This proposal adds that **review/audit** capability as an extension of the
existing skill, not a separate skill, so that the best-practice definitions
remain a single source of truth.

## Design decisions

Settled during the brainstorming dialogue (2026-06-25):

1. **Deliverable** — inline prioritised punch-list by default, with an offered
   (not automatic) written report for non-trivial pipelines.
2. **Architecture** — extend the existing skill with one new reference,
   `references/reviewing.md`, holding only the review *methodology*. The
   best-practice *definitions* stay in the existing non-negotiables and
   reference docs; `reviewing.md` cross-references them rather than restating
   them, so the two cannot drift.
3. **Boundary** — review-then-offer-fixes. The review reads and reports, then
   offers to apply fixes and proceeds on a yes. It never edits files before the
   user says go.
4. **Static vs dynamic** — static-first, tooling optional. The methodology is a
   structured static read that works on any pipeline (even a single pasted
   Snakefile). When the pipeline is actually runnable in the environment, the
   review additionally folds in `snakemake --lint` and `snakemake -n` as
   corroborating signals; when it is not, it says so and reviews statically.

## What is built

### 1. `references/reviewing.md` (new)

The heart of the feature. Contains:

**The review walk** — a fixed outermost-to-innermost order so reviews are
deterministic and nothing is skipped:

1. **Layout & structure** — standard `workflow/` + `config/` + `results/` +
   `resources/` layout; rules in topical `.smk` files; schemas in
   `workflow/schemas/`; helpers isolated in `common.smk`.
2. **Reproducibility** — every non-trivial rule has `conda:` or `container:`
   with pinned versions; no global tool installs. (Highest-value class.)
3. **Config hygiene** — runtime values (threads/resources/outdir) leaking into
   `config.yaml`; schema validation present; sample sheet validated.
4. **Idioms** — `lambda` inside rules; hand-rolled aggregation that should be
   `collect`/`lookup`/`branch`; `.replace()` path surgery that should be
   `subpath`; missing `log:`; `run:` blocks doing non-trivial work.
5. **Optimisation** — intermediates that should be `temp()`; a `wrapper:` that
   exists for the tool; opportunities for `pipe()`, `multiext`, better
   `threads`/`resources`; `--sdm` vs deprecated flags.
6. **Modernisation** — v9 opportunities: deprecated v7/v8 patterns
   (`--use-conda`, `remote://`), profile filename, v9 helper functions,
   `pathvars` for configurable path roots.
7. **Tooling corroboration** (if runnable) — fold in `snakemake --lint` and
   `snakemake -n` output; otherwise note "not runnable here, static only".

**Finding shape** — every finding is phrased as: *what* + *which file/rule* +
*which best-practice (cross-referenced to the relevant reference doc)* +
*suggested fix*.

**Severity model** — three levels:

- **Blocker** — breaks reproducibility or correctness: a rule with no
  `conda:`/`container:`, unpinned versions, a `lambda` the linter fails on,
  hardcoded absolute paths.
- **Should-fix** — works but fragile or non-idiomatic: threads in config,
  missing `log:`, missing schema validation, hand-rolled aggregation.
- **Nice-to-have** — optimisation/modernisation: `temp()` opportunities, an
  available wrapper, v9 helpers/`pathvars`, mermaid reports.

**Output format** —

- *Default (inline punch-list):* findings grouped by severity, blockers first,
  each one line — severity, `file:rule`, the issue, the fix, the reference doc
  to consult. Ends with a one-line tally and the fix offer.
- *Report doc (offered for non-trivial pipelines):* the same findings written
  to `<pipeline>/PIPELINE_REVIEW.md` (or a user-chosen path) with a short
  summary header. Offered, not automatic. "Non-trivial" ≈ more than ~10 rules
  or more than ~5 findings.

**Fix hand-off** — after the punch-list, the review offers to apply fixes
("fix the blockers / the top N / all?"). On a yes it applies them grouped by
severity (blockers first), drawing on the existing authoring references, and
re-runs the verification gates afterward if the pipeline is runnable. It never
edits before the user says go.

### 2. `SKILL.md` wiring (edits)

- Broaden the frontmatter `description` and the "When to use" section to include
  reviewing/auditing an existing pipeline.
- Add a Decision-flow row: "Review/audit an existing pipeline → reviewing.md".
- Add a References-table row for `references/reviewing.md`.
- Add one line to "Common mistakes" pointing reviewers at `reviewing.md`.

No assets change.

## Out of scope

- No new standalone skill; no duplication of the best-practice rubric.
- No auto-fixing without explicit user approval.
- No requirement that the pipeline be runnable.
- TDD hardening of this new reference (pressure/retrieval testing per
  `superpowers:writing-skills`) is acknowledged but tracked separately, as with
  the existing `2026-06-05-tdd-hardening.md` proposal.

## Verification

The new reference is primarily a **technique/reference** surface, so it is
validated by retrieval and application rather than pressure scenarios: given a
deliberately flawed sample pipeline, an agent following `reviewing.md` should
produce the expected findings at the expected severities, in the walk order,
each cross-referencing the correct existing reference doc.
