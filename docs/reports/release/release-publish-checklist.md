# Release Publish Checklist

Task: 02_RELEASE Final Release Checklist

Status: Ready

Priority: P0

## Findings

- Version: `0.3.0-beta`
- Build: `3`
- Local tag created: `v0.3.0-beta`
- Release artifact exists: `dist.noindex/NotchMuse.dmg`
- SHA-256 exists: `dist.noindex/NotchMuse.dmg.sha256`
- Current SHA-256:

```text
f956eb31915ea8c69431c93542e6a34797d3e081c4f493872faa254c79664c99  NotchMuse.dmg
```

## Problems Found

- No release artifact blocker found.
- GitHub remote is not configured locally, so publishing must happen after a remote is added or through the GitHub UI.

## Recommended Actions

- Push branch and tag after GitHub remote is configured.
- Create GitHub Pre-release and upload `NotchMuse.dmg`.

## Need PM Decision

- Confirm GitHub repository remote URL before push/publish.
