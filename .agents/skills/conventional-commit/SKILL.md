---
name: conventional-commit
description: "Use when writing or refining a Conventional Commit subject line; use change-description for substantive bodies."
user-invocable: false
---

# Conventional Commits

## Related Skills

- `change-description` — writes the description body.

## Commit Messages

Create or refine commit messages in Conventional Commits style.

## Subject Format

`<type>(<scope>): <summary>`

Rules:

- `type` is required: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`, `perf`
- `scope` is optional and should be a short area name like `ci`, `api`, `db`, `ui`, `server`, `client`, or a module name.
- `summary` is required: imperative, specific, no trailing period, max 72 chars

Examples:

- `fix(ci): skip Discord alerts for merge queue failures`
- `feat(wallet): add change output selection`
- `docs(api): clarify gateway auth flow`

## Body

Use a blank line after the subject. For a substantive change, write the body
with `change-description`; it explains the decision and behavior rather than
repeating the subject or enumerating the diff.

Do not add:

- breaking-change markers or footers
- sign-offs
- push operations

## Guidance

- Match the type to the intent of the change, not the subsystem name.
- Prefer the smallest accurate scope.
- Consider checking history of affected files (e.g. `git log -- <paths...>`) as help.
