# writing-snakemake-pipelines

A Claude Code skill for authoring [Snakemake](https://snakemake.readthedocs.io/)
workflows that follow the official best practices.

Targets Snakemake v8+. Bioinformatics-flavored examples.

## Status

**Draft.** The skill content is complete and authoritative (it cross-references
the official `docs/snakefiles/best_practices.rst`), but it has not yet been
hardened with the subagent-driven pressure tests described in
`docs/proposals/2026-06-05-tdd-hardening.md`.

## What it does

The skill triggers whenever Claude is asked to create, edit, or scaffold a
Snakemake workflow. It enforces:

- The standard `workflow/` + `config/` + `results/` + `resources/` layout.
- Conda or container-based reproducibility per rule.
- Config-file-driven design with JSON schema validation.
- v8 CLI conventions (`--sdm conda`, not `--use-conda`).
- Use of `snakemake-wrappers` and semantic helpers (`collect`, `lookup`, `branch`).
- Linting (`snakemake --lint`), formatting (`snakefmt`), and dry-run as gates
  before claiming work is done.

The full set of rules is in `SKILL.md`.

## Layout

```
SKILL.md                    # the always-loaded entry point
references/                 # load-on-demand deeper material
  project-structure.md
  rule-anatomy.md
  semantic-helpers.md
  deployment.md
  configuration.md
  modularization.md
  testing-and-ci.md
  v7-to-v8-migration.md
  verification-checklist.md
assets/                     # ready-to-copy templates
  workflow/...              # standard project skeleton
  config/...
  .github/workflows/main.yml
  .gitignore
docs/
  proposals/                # design proposals not yet enacted
```

## Installation

For Claude Code:

```bash
git clone https://github.com/<you>/writing-snakemake-pipelines-skill.git
ln -s "$(pwd)/writing-snakemake-pipelines-skill" \
      ~/.claude/skills/writing-snakemake-pipelines
```

The skill is then auto-discovered by Claude Code via its description.

## Authority

The non-negotiables in `SKILL.md` are taken directly from
`docs/snakefiles/best_practices.rst` in the
[snakemake repository](https://github.com/snakemake/snakemake). When in doubt,
that file is the source of truth and this skill should be updated to track it.
