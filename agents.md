# Agent Instructions

## Commit Convention

Use Conventional Commits for every commit.

Format:

```text
<type>(<scope>): <summary>
```

Rules:

- Use a lowercase type such as `feat`, `fix`, `docs`, `test`, `refactor`, `chore`, `build`, `ci`, `perf`, or `style`.
- Include a short lowercase scope that matches the area changed, such as `hosts`, `workspace`, `l10n`, `terminal`, or `vault`.
- Write the summary in English, imperative mood, and keep it concise.
- Do not end the summary with a period.
- Examples: `feat(hosts): make display name optional`, `fix(workspace): stabilize vault loading states`.

## Schema Versioning

- Only bump remote sync/vault data schema versions for incompatible breaking changes that older apps cannot safely read, preserve, merge, or write back.
- Do not bump remote sync/vault data schema versions for compatible changes such as optional JSON fields, ignorable records, or fields that can be defaulted when absent.
- Local Drift database schema migrations are separate; see `docs/development_schema_versioning.md` before changing version constants.
