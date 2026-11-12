# NotchMuse Collaboration Rules

## Autonomous Execution

PMs and agents should continue normal project work without repeatedly waiting
for confirmation. They may read project state, manage existing workspaces,
assign bounded tasks, fix confirmed bugs, adjust UI, build and test candidates,
write test evidence, update project documents, and archive obsolete workspace
registrations.

Ask only before an irreversible high-risk action: deleting core code or user
data, changing the product's core architecture or stable player behavior, or
publishing a public release.

## Project Handoff

Start with `docs/project/NOTCHMUSE_MASTER_HANDOFF.md`, `docs/project/PROJECT_STATUS.md`,
`docs/project/PROJECT_HANDOFF.md`, `docs/project/ROADMAP.md`,
`docs/project/TASK_BOARD.md`, and `CHANGELOG.md`. Update `docs/project/PROJECT_HANDOFF.md` with the
current version, branch, build, completed work, open issues, blockers, and next
phase before implementation.

## Workspace Discipline

Use only `00_PM` through `07_QA`. Reuse an existing responsibility workspace;
do not create duplicate numbered workspaces. Archive completed or obsolete
registrations without deleting their Git history. Update `docs/project/TASK_BOARD.md` when
a task changes state.

## Release Boundary

Local candidate development, building and testing are autonomous. Each App public
release needs one Product Owner authorization for that release. That authorization
covers related Git push, tag/Release/assets, website deployment, bilingual notes,
Sparkle promotion and final public verification; do not ask separately per step.
Approval does not carry to a later App release. Confirmed routine website/SEO work
includes tests, GitHub synchronization, deployment and public verification.
Pause only for material safety risks, major test failures or scope beyond approval;
never skip verification to claim completion. Follow every item in
[RELEASE_CHECKLIST](docs/project/RELEASE_CHECKLIST.md) and the sequence in
[UPDATE_RELEASE_AUTOMATION](docs/project/UPDATE_RELEASE_AUTOMATION.md).
Report deployed, verified and untested separately; GitHub Release alone is not
old-user update delivery. Keep complete English-first/Chinese-second notes.

## Canonical Documentation

Keep `docs/project/NOTCHMUSE_MASTER_HANDOFF.md`, `docs/project/PROJECT_STATUS.md`,
`docs/project/TASK_BOARD.md`, and `docs/project/THREAD_REGISTRY.md` synchronized
after major features, releases, architecture or product-policy changes, and
thread archival. Historical checkpoints belong in `docs/archive/` or
`docs/reports/`, not in a second root-level PM document.
