# Pipeline-Review Capability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a review/audit capability to the `writing-snakemake-pipelines` skill: a new `references/reviewing.md` methodology plus `SKILL.md` wiring, validated against a deliberately-flawed sample pipeline.

**Architecture:** The review is a *lens* over the skill's existing best-practice definitions. One new reference doc holds only the review methodology (walk order, severity model, output format, fix hand-off) and cross-references the existing non-negotiables/reference docs rather than restating them. `SKILL.md` gains triggers and table rows. A test fixture under `tests/review-fixture/` (a broken-on-purpose workflow + an expected-findings list) is the validation harness: an agent following `reviewing.md` must reproduce the expected findings.

**Tech Stack:** Markdown (skill content), Snakemake v9 (fixture workflow), subagent dispatch for validation. No application code.

## Global Constraints

- Target Snakemake **v9** (the skill was retargeted from v8+ to v9). Use `--sdm`, `profile.yaml`, v9 helpers.
- **No duplication** of best-practice definitions: `reviewing.md` cross-references existing reference docs (`deployment.md`, `semantic-helpers.md`, `configuration.md`, `rule-anatomy.md`, `project-structure.md`, `testing-and-ci.md`, `v8-to-v9-migration.md`, `verification-checklist.md`) by name; it does not restate the rules.
- Cross-references use plain reference-doc filenames (e.g. `see semantic-helpers.md`), matching the style already used across the skill.
- The review **never edits files before the user approves**; fixing is an offered follow-up.
- Spec of record: `docs/proposals/2026-06-25-pipeline-review.md`.
- Commit message style: imperative subject + `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>` trailer (match repo history).

---

### Task 1: Validation fixture — a deliberately-flawed pipeline + expected findings

This is the test, written first. It defines what a correct review must catch, before `reviewing.md` exists. The fixture is a tiny but broken-on-purpose Snakemake workflow seeded with one issue per rubric dimension; the expected-findings file is the answer key.

**Files:**
- Create: `tests/review-fixture/workflow/Snakefile`
- Create: `tests/review-fixture/config/config.yaml`
- Create: `tests/review-fixture/EXPECTED-FINDINGS.md`
- Create: `tests/review-fixture/README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: a fixture directory `tests/review-fixture/` and an answer key `EXPECTED-FINDINGS.md` that Task 4 dispatches a subagent against. The answer key's finding IDs (F1–F9) and severities are referenced verbatim by Task 4.

- [ ] **Step 1: Write the flawed Snakefile**

Create `tests/review-fixture/workflow/Snakefile`. Each numbered comment marks a deliberate flaw the review must catch — but the comments are the only documentation; the rules themselves read as a plausible (bad) real pipeline.

```python
from snakemake.utils import min_version

min_version("7.0")  # F9: stale min_version, pre-v9

configfile: "config/config.yaml"

import pandas as pd

samples = pd.read_table(config["samples"]).set_index("sample", drop=False)
# F4: no validate() of config or samples (no schema validation)

outdir = config["outdir"]  # F8: central outdir variable + string concat


rule all:
    input:
        expand(outdir + "/sorted/{sample}.bam", sample=samples.index),


rule align:
    input:
        reads=lambda wildcards: samples.loc[wildcards.sample, "fastq"],  # F3: lambda in rule
        ref="/data/genomes/hg38.fa",  # F5: hardcoded absolute path
    output:
        outdir + "/aligned/{sample}.bam",  # F8: outdir concat
    threads: config["threads"]  # F2: threads pulled from config
    shell:
        "bwa mem -t {threads} {input.ref} {input.reads} | samtools view -b - > {output}"
        # F1: no conda/container; F7: missing log:


rule sort:
    input:
        outdir + "/aligned/{sample}.bam",
    output:
        outdir + "/sorted/{sample}.bam",  # F6: intermediate aligned bam never marked temp()
    conda:
        "envs/samtools.yaml"  # F1b: env exists but unpinned (see Step 2)
    shell:
        "samtools sort -o {output} {input}"
        # F6b: hand-rolled samtools sort where a wrapper exists; F7: missing log:
```

- [ ] **Step 2: Write the unpinned conda env and the config**

Create `tests/review-fixture/workflow/envs/samtools.yaml`:

```yaml
channels:
  - bioconda
  - conda-forge
dependencies:
  - samtools          # F1b: unpinned version
```

Create `tests/review-fixture/config/config.yaml`:

```yaml
samples: config/samples.tsv
outdir: results
threads: 8          # F2: runtime value in config
```

- [ ] **Step 3: Write the expected-findings answer key**

Create `tests/review-fixture/EXPECTED-FINDINGS.md`:

```markdown
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

Total: 4 blockers, 4 should-fix, 3 nice-to-have.
```

- [ ] **Step 4: Write the fixture README**

Create `tests/review-fixture/README.md`:

```markdown
# Review fixture

A deliberately-flawed Snakemake workflow used to validate
`references/reviewing.md`. Every flaw is tagged `F<n>` in the source and
catalogued in `EXPECTED-FINDINGS.md`. Do NOT "fix" this workflow — its
brokenness is the point.
```

- [ ] **Step 5: Commit**

```bash
git add tests/review-fixture/
git commit -m "$(cat <<'EOF'
Add review fixture: flawed pipeline + expected findings

Validation harness for the forthcoming references/reviewing.md. A
broken-on-purpose v9 workflow seeded with one issue per rubric dimension,
plus an answer key (F1-F9) with severities and reference-doc cross-refs.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Write `references/reviewing.md`

The methodology document. Written section by section in the spec's order. Cross-references existing reference docs; restates no rules.

**Files:**
- Create: `references/reviewing.md`

**Interfaces:**
- Consumes: the existing reference docs (by name) and the non-negotiables in `SKILL.md`.
- Produces: `references/reviewing.md`, referenced by the `SKILL.md` edits in Task 3 and exercised by Task 4.

- [ ] **Step 1: Write the header, overview, and review walk**

Create `references/reviewing.md` starting with:

````markdown
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
````

- [ ] **Step 2: Write the finding shape and severity model**

Append:

````markdown
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
````

- [ ] **Step 3: Write the output format**

Append:

````markdown
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
````

- [ ] **Step 4: Write the fix hand-off and a closing red-flags note**

Append:

````markdown
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
````

- [ ] **Step 5: Verify cross-references resolve**

Run: `for f in project-structure deployment configuration semantic-helpers rule-anatomy modularization v8-to-v9-migration verification-checklist; do test -f "references/$f.md" && echo "OK $f" || echo "MISSING $f"; done`
Expected: all `OK` (every doc cited in `reviewing.md` exists).

- [ ] **Step 6: Commit**

```bash
git add references/reviewing.md
git commit -m "$(cat <<'EOF'
Add references/reviewing.md pipeline-review methodology

Static-first review walk (layout, reproducibility, config, idioms,
optimisation, modernisation, tooling), severity model, inline punch-list +
offered report, and review-then-offer-fixes hand-off. Cross-references the
existing reference docs; restates no rules.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Wire `reviewing.md` into `SKILL.md`

Broaden the skill's triggers and add table rows so the review methodology is discoverable.

**Files:**
- Modify: `SKILL.md` (frontmatter `description`; "When to use"; Decision flow; References table; Common mistakes)

**Interfaces:**
- Consumes: `references/reviewing.md` from Task 2.
- Produces: updated `SKILL.md` triggers; no downstream consumers.

- [ ] **Step 1: Broaden the frontmatter description**

In `SKILL.md`, change the `description:` line to add reviewing. Current:

```
description: Use when creating, editing, or scaffolding Snakemake workflows — Snakefiles, .smk rule files, workflow/ projects, config/schema files, conda envs per rule, or anything involving the snakemake CLI. Bioinformatics-flavored. Targets Snakemake v9.
```

Replace with:

```
description: Use when creating, editing, scaffolding, OR reviewing/auditing Snakemake workflows — Snakefiles, .smk rule files, workflow/ projects, config/schema files, conda envs per rule, or anything involving the snakemake CLI. Bioinformatics-flavored. Targets Snakemake v9.
```

- [ ] **Step 2: Add a "When to use" trigger**

In the "When to use" bullet list, after the existing requests bullet, add:

```
- Requests like "review this pipeline", "audit my workflow", "is this Snakefile idiomatic?", "what could be improved here?" → load `references/reviewing.md`.
```

- [ ] **Step 3: Add a Decision-flow row**

In the Decision flow block, add this row (above "Before claiming the work is done"):

```
Review/audit an existing pipeline               → reviewing.md
```

- [ ] **Step 4: Add a References-table row**

In the "References (load on demand)" table, add:

```
| `references/reviewing.md` | Auditing an existing pipeline against best practices — the review walk, severity model, output format, fix hand-off. |
```

- [ ] **Step 5: Add a Common-mistakes row**

In the "Common mistakes" table, add:

```
| Reviewing a pipeline by ad-hoc skimming | Follow the fixed walk in `reviewing.md` (layout → reproducibility → config → idioms → optimisation → modernisation) so nothing is skipped. |
```

- [ ] **Step 6: Verify the edits landed**

Run: `grep -c "reviewing.md" SKILL.md`
Expected: `4` (When-to-use, Decision flow, References table, Common mistakes).

- [ ] **Step 7: Commit**

```bash
git add SKILL.md
git commit -m "$(cat <<'EOF'
Wire reviewing.md into SKILL.md triggers and tables

Broaden the description and When-to-use to cover reviewing/auditing; add
decision-flow, references-table, and common-mistakes rows pointing at the
new review methodology.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Validate the methodology against the fixture

The GREEN/REFACTOR gate. Dispatch a fresh subagent that uses the skill to review the Task 1 fixture, then compare its findings to the answer key. Close any gaps in `reviewing.md`.

**Files:**
- Modify (only if gaps found): `references/reviewing.md`

**Interfaces:**
- Consumes: `tests/review-fixture/` and `EXPECTED-FINDINGS.md` (Task 1); `references/reviewing.md` (Task 2); `SKILL.md` wiring (Task 3).
- Produces: a validated methodology; no new files.

- [ ] **Step 1: Dispatch a review subagent against the fixture**

Dispatch a subagent (general-purpose) with a self-contained prompt: "Using the writing-snakemake-pipelines skill, review the Snakemake pipeline at `tests/review-fixture/workflow/` against current best practices. Produce the inline punch-list exactly as the skill's `reviewing.md` specifies. Do not read `EXPECTED-FINDINGS.md`. Do not edit any files." Capture its punch-list output.

- [ ] **Step 2: Score the output against the answer key**

Compare the subagent's findings to `tests/review-fixture/EXPECTED-FINDINGS.md`. Record, for each of F1–F9 (plus F1b, F6b): found? correct severity? correct reference-doc cross-ref? A finding counts as passing only if present AND at the expected severity tier.

Expected: all 11 findings present at the right severity. (Acceptable failure: the agent may bundle F1+F1b or F6+F6b — count those as passes if both ideas are named.)

- [ ] **Step 3: Close gaps in `reviewing.md`**

For any finding the agent missed or mis-severitised, identify which part of the walk/severity model was ambiguous and tighten that wording in `references/reviewing.md`. (No code; edit the doc.) If all 11 passed on the first run, skip to Step 5 with no change.

- [ ] **Step 4: Re-run the validation**

Repeat Steps 1–2 with a fresh subagent. Expected: all 11 findings now present at the right severity.

- [ ] **Step 5: Commit (only if `reviewing.md` changed)**

```bash
git add references/reviewing.md
git commit -m "$(cat <<'EOF'
Tighten reviewing.md after fixture validation

Close wording gaps surfaced when a review subagent missed/mis-rated fixture
findings; methodology now reproduces all expected findings at the expected
severities.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

If `reviewing.md` was unchanged (passed first try), record that in the task notes and make no commit.

---

## Self-Review

**Spec coverage** — checked each spec section against a task:

- Deliverable C (inline punch-list + offered report) → Task 2 Step 3. ✓
- Architecture B (extend skill, new reference, cross-ref no duplication) → Tasks 2 & 3; Global Constraints. ✓
- Boundary B (review-then-offer-fixes, no edit before go) → Task 2 Step 4. ✓
- Static-first + optional tooling A → Task 2 Step 1 (walk item 7). ✓
- The review walk (7 items) → Task 2 Step 1. ✓
- Finding shape + severity model → Task 2 Step 2. ✓
- SKILL.md wiring (4 edits) → Task 3. ✓
- Verification (flawed sample → expected findings) → Tasks 1 & 4. ✓
- Out-of-scope items (no standalone skill, no auto-fix, not requiring runnable) → respected; no task adds them. ✓

**Placeholder scan** — no TBD/TODO; all doc content and fixture code is shown verbatim; commit messages are concrete. ✓

**Type/name consistency** — finding IDs F1–F9 (+F1b, F6b) defined in Task 1 Step 3 are the same IDs scored in Task 4 Step 2; reference-doc filenames cited in `reviewing.md` (Task 2) match the files verified in Task 2 Step 5 and Global Constraints. ✓
