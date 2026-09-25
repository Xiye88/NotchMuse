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

Start with `PROJECT_STATUS.md`, `PROJECT_HANDOFF.md`, `ROADMAP.md`,
`TASK_BOARD.md`, and `CHANGELOG.md`. Update `PROJECT_HANDOFF.md` with the
current version, branch, build, completed work, open issues, blockers, and next
phase before implementation.

## Workspace Discipline

Use only `00_PM` through `07_QA`. Reuse an existing responsibility workspace;
do not create duplicate numbered workspaces. Archive completed or obsolete
registrations without deleting their Git history. Update `TASK_BOARD.md` when
a task changes state.

## Release Boundary

Building and verifying a local candidate is autonomous. Pushing, tagging, or
publishing a public release requires final Product Owner approval.
