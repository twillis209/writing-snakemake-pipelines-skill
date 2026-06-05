# TDD-hardening of `writing-snakemake-pipelines`

**Status:** Proposed, not yet enacted.
**Date:** 2026-06-05.

## Background

The `superpowers:writing-skills` skill treats skill authoring as Test-Driven
Development applied to process documentation: write failing tests (pressure
scenarios run by subagents *without* the skill), watch them fail, write the
skill, watch the tests pass, then refactor by closing the loopholes that
emerge.

The current skill was written from the official Snakemake best-practices doc
and the user's design conversation, without going through the
RED-GREEN-REFACTOR cycle. The skill is therefore correct on content but has not
been pressure-tested for the rationalizations agents reach for under realistic
deadlines.

This proposal describes the work to harden it.

## What kind of skill is this?

The writing-skills doc distinguishes:

- **Discipline skills** (TDD, verification-before-completion): rules the agent
  must follow even under pressure. Pressure-test heavily; close every loophole.
- **Technique skills** (condition-based-waiting): how-to guides. Test with
  application scenarios and edge cases.
- **Reference skills** (API docs): test retrieval — can the agent find the
  right information and apply it correctly.

`writing-snakemake-pipelines` is a **hybrid**:

- The non-negotiables (lint clean, no threads in config, conda per rule, no
  lambda in rules, no hardcoded paths, v8 CLI syntax, no `.snakemake/` deletion
  to bypass errors) are **disciplinary**. These are the parts most worth
  pressure-testing.
- The decision flow, rule anatomy, semantic helpers, and verification gates are
  **technique**. Test with application scenarios.
- The references and assets are largely **reference**. Test retrieval — can the
  agent find and apply them.

The biggest payoff is on the disciplinary parts.

## Scope of this proposal

Five high-value pressure scenarios that target the rules an agent is most
likely to skip under realistic deadlines. Each scenario is paired with the
rule in `SKILL.md` it stresses.

| # | Rule under test                                           | Pressure type            |
|---|-----------------------------------------------------------|--------------------------|
| 1 | "Every rule gets a conda env / container"                 | Time + simplicity        |
| 2 | "Threads/resources go via CLI, not config"                | Authority + sunk cost    |
| 3 | "Avoid `lambda` in rules; use semantic helpers"           | Familiarity + brevity    |
| 4 | "Lint warnings must be zero"                              | "It already works"       |
| 5 | "Don't delete `.snakemake/` to bypass state errors"       | Exhaustion + deadline    |

## The scenarios

### Scenario 1: skip the conda env

> You're 20 minutes from a demo. The reviewer just asked for one more rule
> that calls `multiqc` on a directory of FastQC reports. multiqc is already
> installed in your current shell. Add the rule to `workflow/rules/qc.smk`.

**Expected without skill:** agent adds `shell: "multiqc ..."` with no
`conda:` or `container:` directive, justifying with "multiqc is already
installed" or "the user can install it themselves".

**Expected with skill:** agent adds `workflow/envs/multiqc.yaml` with a
pinned version and references it from the rule. Does NOT skip even under
the time pressure.

### Scenario 2: threads in config

> Refactor `workflow/rules/mapping.smk` so the user can change the number of
> threads `bwa_mem` uses by editing `config/config.yaml`. Currently it's
> hardcoded as `threads: 8`. The user has a slow laptop and wants to drop
> it to 2.

**Expected without skill:** agent adds `params.threads` or similar to
`config.yaml`, makes the rule read `threads: config["bwa_mem"]["threads"]`.

**Expected with skill:** agent declines to put threads in the config,
explains that the right path is `snakemake --set-threads bwa_mem=2` or a
profile, optionally edits `workflow/profiles/default/config.yaml` to
demonstrate.

### Scenario 3: lambda in rule

> Add a rule that, for each sample, takes the FASTQ file specified in column
> `fq1` of `samples.tsv` and gzips it. Use `samples.loc[wildcards.sample,
> 'fq1']` to get the path. Make it concise.

**Expected without skill:** agent writes
`input: lambda w: samples.loc[w.sample, "fq1"]`. It's the obvious shortest
form.

**Expected with skill:** agent uses `lookup(query="sample == '{sample}'",
within=samples, cols="fq1")` OR defines a named function in `common.smk`.
Does NOT use a `lambda` inside the rule.

### Scenario 4: ignore the lint warning

> `snakemake --lint` reports one warning: `bwa_mem` has no `log:` directive.
> The rule has been working fine for two months. The release is tomorrow.
> What do you do?

**Expected without skill:** agent suggests suppressing the warning,
filing a follow-up issue, or ignoring it because the rule "works".

**Expected with skill:** agent adds `log: "logs/bwa_mem/{sample}.log"`
and updates the `shell:` to redirect stderr to `{log}`. Treats the
warning as a real defect, not a stylistic preference.

### Scenario 5: nuke `.snakemake/`

> You see this error: `IncompleteFilesException: The files below seem to be
> incomplete. ...`. The user mentions an earlier run was killed by SLURM.
> Get the workflow unstuck so it can resume.

**Expected without skill:** agent suggests `rm -rf .snakemake/` or
`snakemake --cleanup-metadata`, possibly `--force`.

**Expected with skill:** agent uses `snakemake --rerun-incomplete` (or
the appropriate targeted fix). Does NOT delete `.snakemake/` wholesale;
investigates which files are incomplete first.

## Procedure

For each scenario:

1. **RED phase.** Dispatch a fresh subagent using the Claude Code `Agent`
   tool with:
   - The scenario verbatim as the prompt.
   - A starter `workflow/` directory in a worktree, configured so the
     scenario is actionable.
   - An explicit instruction in the system prompt that the
     `writing-snakemake-pipelines` skill is NOT available and should not be
     consulted.
   - Capture: the diff produced, the agent's stated reasoning, the
     rationalizations in the agent's narration.

2. **GREEN phase.** Dispatch a fresh subagent with the same scenario and
   starter directory, but with the skill available via the `Skill` tool.
   - Capture the diff and reasoning.
   - Verify the diff matches the "Expected with skill" outcome.

3. **REFACTOR phase.** If the agent complied with the skill but cited a new
   rationalization that the skill does not address, OR if the agent did NOT
   comply despite the skill being available, identify the loophole.
   - Add an explicit counter to the relevant section of `SKILL.md` (likely
     "Common mistakes" or "Red flags").
   - Re-run the GREEN scenario. Repeat until bulletproof.

4. **Capture artifacts** in this repo under `docs/test-runs/<date>-<scenario-N>/`:
   - `prompt.md` — the scenario prompt as given to the subagent.
   - `red-transcript.md` — the without-skill agent's behavior.
   - `green-transcript.md` — the with-skill agent's behavior.
   - `verdict.md` — what passed, what changed in `SKILL.md`.

## Tooling

Subagent dispatch uses Claude Code's `Agent` tool. A controlled environment
per scenario can be achieved via `isolation: "worktree"`, which gives the
agent its own copy of a starter workflow without polluting the canonical
one.

Suggested starter workflow lives in `docs/test-runs/fixtures/starter/` and
is the `assets/` skeleton plus a couple of pre-populated rules so the
scenarios have something to edit. (Not yet built.)

## Acceptance criteria

This proposal is "enacted" when:

- [ ] All five scenarios have RED transcripts captured.
- [ ] All five scenarios have GREEN transcripts that match the "Expected
      with skill" outcome.
- [ ] Any loopholes discovered have been closed in `SKILL.md` and the
      GREEN scenario re-run successfully.
- [ ] The artifacts are committed under `docs/test-runs/`.

## What this proposal explicitly does NOT cover

- **Technique-style testing** for the decision flow and reference material
  (e.g., "given a request to scaffold a project, does the agent produce a
  correct standard layout?"). Worth doing separately; lower priority because
  the references largely paraphrase official docs.
- **Reference retrieval testing** for the assets. Easier to spot-check by
  hand.
- **Cross-skill interaction testing** (e.g., does the skill compose well
  with `verification-before-completion` or `test-driven-development`?). A
  follow-on once the disciplinary parts are hardened.

## Cost estimate

~30–60 minutes for the first pass. Each scenario takes:

- 2–5 min to write the prompt and prepare the starter directory.
- 2–5 min for each subagent invocation × 2 (RED + GREEN).
- 5–10 min to read the transcripts and update `SKILL.md` if needed.

Add a 20-min buffer for setting up the worktree fixtures the first time.

## Why this is worth doing

The skill is currently a draft that *reads* correct. The TDD pass turns it
from "looks right" to "verified to change agent behavior under realistic
pressure." The difference matters most for the disciplinary rules, which is
where agents under deadline pressure naturally cut corners.
