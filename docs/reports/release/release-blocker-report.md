# Task Completion Report

Task: Release QA / Release Blocker Report

Status: Blocked

Priority: P0

## Findings

- Developer ID signing is supported by the release scripts via `NOTCHMUSE_SIGN_IDENTITY="Developer ID Application: ..."` when running `./scripts/build_release.sh` or `./scripts/build_dmg.sh`.
- Default release output is ad-hoc signed because `NOTCHMUSE_SIGN_IDENTITY` defaults to `-`.
- `security find-identity -v -p codesigning` returned `0 valid identities found`, so this machine cannot produce a Developer ID signed release right now.
- Current app signature verifies locally with `codesign --verify --deep --strict --verbose=2 dist.noindex/NotchMuse.app`.
- Current app signature is ad-hoc: `codesign -dv --verbose=4 dist.noindex/NotchMuse.app` reports `Signature=adhoc` and `TeamIdentifier=not set`.
- Current DMG verifies structurally with `hdiutil verify dist.noindex/NotchMuse.dmg`.
- Current DMG is not code signed: `codesign -dv --verbose=4 dist.noindex/NotchMuse.dmg` reports `code object is not signed at all`.
- Notarization tooling exists locally: `xcrun --find notarytool` and `xcrun --find stapler` both resolve under CommandLineTools.
- No release script currently submits the DMG to Apple notarization.
- No release script currently staples a notarization ticket after acceptance.
- `xcrun stapler validate -v dist.noindex/NotchMuse.app` reports no stapled ticket.
- `xcrun stapler validate -v dist.noindex/NotchMuse.dmg` reports no stapled ticket.
- Gatekeeper rejects the current app: `spctl --assess --type execute --verbose=4 dist.noindex/NotchMuse.app` returns `rejected`.
- Clean DMG install layout is present: read-only mount contains `NotchMuse.app` and an `Applications` symlink pointing to `/Applications`.

## Problems Found

- Blocker: no valid local Developer ID Application certificate is available.
- Blocker: current app is ad-hoc signed, not Developer ID signed.
- Blocker: current DMG is unsigned.
- Blocker: notarization has not been performed and no notarization credentials/profile were confirmed.
- Blocker: no stapled ticket exists on the app or DMG.
- Blocker: Gatekeeper rejects the current app.
- Gap: release scripts verify signing and DMG checksum, but do not perform notarization or stapling.

## Recommended Actions

- Install or provide access to a valid Apple Developer ID Application certificate on the release machine.
- Build the RC with `NOTCHMUSE_SIGN_IDENTITY="Developer ID Application: <Name> (<TEAMID>)" ./scripts/build_release.sh 0.3.0-beta <build>`.
- Configure notarization credentials for `xcrun notarytool`, preferably with a keychain profile.
- Submit the signed DMG with `xcrun notarytool submit dist.noindex/NotchMuse.dmg --keychain-profile <profile> --wait`.
- After notarization is accepted, run `xcrun stapler staple dist.noindex/NotchMuse.dmg`.
- Re-run `xcrun stapler validate -v dist.noindex/NotchMuse.dmg`, `spctl --assess --type execute --verbose=4 dist.noindex/NotchMuse.app`, and a clean DMG install check.
- Optionally add notarization and stapling steps to `scripts/build_release.sh` once credentials are available.

## Need PM Decision

- Confirm who owns the Developer ID certificate and Apple notarization credentials for beta release.
- Decide whether to block public beta until Developer ID signing, notarization, stapling, and Gatekeeper acceptance all pass.
- Decide whether release automation should fail hard when `NOTCHMUSE_SIGN_IDENTITY` is still `-` for public RC builds.
