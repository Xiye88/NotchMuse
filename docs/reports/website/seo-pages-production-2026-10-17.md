# Website topic pages — production closure

2026-10-17, Asia/Shanghai. Status: publication authorized; deployment in progress.

## Scope and authorization

Product Owner explicitly approved GitHub synchronization and public website publication and asked for a preview. Existing responsibility06_DOCS is reused. Source includes website-only reconciliation of the previously deployed7784fcd baseline and ten new static EN/ZH guide pages, homepage guide discovery and sitemap12 URLs. No app source, version, build, tag, release asset or official feed edit is included.

## Verification before publication

Four browser/static suites passed in the implementation workspace. Public baseline bytes were checked against7784fcd before editing. A website-only patch passed application checks against origin/main cb79f35 and was applied to a clean publication checkout. The source website tree will be byte-compared before commit. A local Chinese Spotify preview is visible in the chat browser.

Implementation details, source limitations and test evidence: [implementation report](seo-scenario-pages-2026-10-17.md). Apple Music footage is explicitly labeled Spotify; LyricsX is an attributed documentation comparison, with no head-to-head execution claim.

```text
Current status: Publication authorized; deployment in progress.
Completed: Ten pages, homepage discovery, metadata and sitemap; four local suites; visual preview; website-only main reconciliation.
Pending confirmation: None for GitHub synchronization or website publication.
Key files: website/; docs/reports/website/seo-scenario-pages-2026-10-17.md; this report.
Next step: Commit/push website scope, stage release directory, switch site service, verify public pages and feed preservation.
Do not repeat: Paid research, App promotion, App build/release, media regeneration or backend analytics setup.
```
