# Orion

Mapping app.

## Workflow docs

Planning and workflow docs (MVP, phases, tasks, discussions, bug notes, the
feature backlog, dependency references) live in `ai/`, which resolves to
`~/ai/orion/` — not in this repo. Start there for context:

- `ai/README.md` — root overview (phases, discussions, ideas backlog).
- `ai/mvp.md` — first-release MVP definition.
- `ai/phase-<N>/<task>/` — per-task `prd.md` → `design.md` → `tasks.md` → `review.md`.
- `ai/discussions/` — dated discussion summaries.
- `ai/backlog.md` — captured feature ideas.
- `ai/bugfix/` — `.fix.md` bug investigation notes.

See `~/.claude/programming.md` for the centralized `~/ai/<repo>/` layout and rules.

## Rules

- **Never push unless explicitly told to.** Do not run `git push` on your own.
