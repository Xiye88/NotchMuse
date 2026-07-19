# Task Completion Report

Task: 02_RELEASE Release Engineering

Status: Ready for unsigned GitHub beta packaging; pending manual first-launch UX proof

Priority: P0

## Findings

- Product Owner changed the current target to GitHub Open Source Beta Release. Developer ID signing and Apple notarization are deferred to the future Distribution Phase.
- `./scripts/build_release.sh 0.3.0-beta 3` completed successfully from a clean release build path and regenerated `dist.noindex/NotchMuse.dmg`.
- Current signing state is expected for this phase: `dist.noindex/NotchMuse.app` is ad-hoc signed. `codesign -dv --verbose=4` reports `Signature=adhoc` and `TeamIdentifier=not set`.
- Current app bundle metadata is correct for this GitHub beta DMG: bundle id `app.notchmuse.mac`, version `0.3.0-beta`, build `3`.
- Current app entitlements include `com.apple.security.automation.apple-events`.
- Local codesign integrity passes: `codesign --verify --deep --strict --verbose=2 dist.noindex/NotchMuse.app`.
- Current DMG is expected to be unsigned for this phase: `codesign -dv --verbose=4 dist.noindex/NotchMuse.dmg` reports `code object is not signed at all`.
- Current DMG checksum verifies with `hdiutil verify dist.noindex/NotchMuse.dmg`.
- Current DMG SHA-256 is `30c54ed542ab6a0e8f6ebefff3c931a4da5f94fdf81108a549b156ca84320e4c`.
- Gatekeeper rejects the current app, as expected for unsigned GitHub beta: `spctl --assess --type execute --verbose=4 dist.noindex/NotchMuse.app` returns `rejected`.
- Clean DMG install layout is valid: read-only mount contains `NotchMuse.app` plus an `Applications` symlink to `/Applications`.
- README now documents Control-click Open and System Settings > Privacy & Security > Open Anyway. Apple Support documents this Open Anyway path and notes the button is available for about an hour after a blocked launch attempt.
- Regenerating the GitHub beta DMG is currently feasible with `./scripts/build_release.sh 0.3.0-beta 3`.

## Problems Found

- No current P0 blocker from Developer ID signing, notarization, stapling, or Gatekeeper acceptance under the new unsigned GitHub beta strategy.
- Expected beta friction: macOS Gatekeeper rejects the app until the user manually approves it.
- Remaining validation gap: the Control-click Open / Open Anyway path still needs screenshot or manual first-launch evidence on a clean user machine after downloading from GitHub Releases.
- Documentation gap fixed in this phase: README and release checklist no longer describe Developer ID signing/notarization as current beta blockers.

## Recommended Actions

- Upload `dist.noindex/NotchMuse.dmg` to GitHub Releases with SHA-256 `30c54ed542ab6a0e8f6ebefff3c931a4da5f94fdf81108a549b156ca84320e4c`.
- Mark the GitHub Release as beta/pre-release and clearly state this is an unsigned open-source beta.
- Include install wording from README in the release body: drag to Applications, Control-click Open, then use System Settings > Privacy & Security > Open Anyway if needed.
- Run one manual clean first-launch check from the uploaded GitHub asset, not only from local `dist.noindex`.
- Keep Developer ID signing, notarization, stapling, and Gatekeeper acceptance in the future Distribution Phase checklist.

## Need PM Decision

- Confirm final GitHub tag and build number. Current verified build is `0.3.0-beta` build `3`.
- Confirm whether the release body should call the artifact `unsigned GitHub beta` or `open-source beta`.
- Confirm who will perform the manual clean-machine Open Anyway proof after upload.
- Next step: publish the regenerated DMG to a GitHub pre-release, then verify download, checksum, drag install, and first launch approval flow from that uploaded asset.
