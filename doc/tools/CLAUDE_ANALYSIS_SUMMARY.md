# AI-assisted findings ↔ production code

This file links findings from AI-assisted reviews (`doc/tools/claude_*.md`, `FEEDBACK.md`) to the production code in `src/` they changed or explain. Production comments never cite these reports directly: their IDs restart each release and their paths move, while a deployed contract's comments cannot be corrected.

## How to use

- Add one entry per code location whenever an AI-assisted finding changes code in `src/`, or explains why it must not change.
- Write the substance into the NatSpec / comment itself; record the link to the finding only here.
- Identify a finding by **report, release, ID and title**, since IDs are not stable across releases.
- Keep `file:line` current when a symbol moves.

Entry template:

```markdown
### S-<n>. `<symbol>` — <what the comment explains>

| | |
|---|---|
| Location | `<path>:<line>`, `<symbol>` |
| Code | `<the line the comment documents>` |
| Comment before | `<the comment with the citation>` (omit for a new entry) |
| Comment now | `<the comment as it stands>` |
| Finding | `<REPORT>.md` (<release>) **<ID>**, "<title>": <disposition> |
| Change applied | <what the finding changed in the code, or "None" and why> |
```

## Entries

None yet. As of v0.3.0, no comment in `src/` cites an AI-assisted report.
