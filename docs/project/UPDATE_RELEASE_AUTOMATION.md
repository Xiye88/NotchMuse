# Update and Release Preparation

This workflow prepares artifacts locally. It does not push, publish, or alter the website.

1. Build a Preview with `NOTCHMUSE_INSTALL_PREVIEW=1 ./scripts/build_preview.sh 41`. Verify its bundle ID is `app.notchmuse.mac.preview`, its update feed is disabled, and the existing stable app is unchanged.
2. After Preview acceptance, build the stable candidate from a committed SHA with `./scripts/build_release.sh 0.8.0 41`. Record `dist.noindex/SHA256SUMS` and `BUILD-INFO.txt`. Run `codesign --verify --deep --strict` and `hdiutil verify`.
3. Run `./scripts/prepare_appcast.sh`. Sparkle's official `generate_appcast` signs the DMG entry with the `notchmuse` EdDSA key in Keychain. For frozen inputs, use `./scripts/prepare_appcast.sh APP DMG NOTES OUTPUT_XML`; defaults use `docs/releases/v$VERSION/RELEASE_NOTES.en.md` and `dist.noindex/appcast-staging/$VERSION-$BUILD/appcast.xml`. Notes are staged as `NotchMuse.md` and must be deployed at `/releases/v$VERSION/NotchMuse.md`. Inspect the generated appcast and verify that its URL, version, build, file length, and signature match the release asset.
4. Obtain separate Product Owner approval before publication. Upload the exact staged DMG to the matching GitHub tag, verify its public download URL, then deploy the signed appcast to `https://notchmuse.com/appcast.xml` and switch website download to the same DMG. Confirm GitHub, appcast, and website checksums and URLs. Do not publish a Preview build.
5. If the asset or feed is wrong, stop promotion. Restore the previous website download and previous signed appcast; do not rewrite a published signed release asset in place. Prepare a higher build instead.

Staged update testing is not complete until a lower-build app downloads and installs a higher-build signed artifact from a non-public test feed, then restarts with the new version and retains settings. An ad-hoc signed candidate may still trigger Gatekeeper on other Macs. Do not claim seamless first-run installation without Developer ID notarization.

## Required delivery verification

A regular public release is not fully delivered until the official feed advertises its build. Verify both `https://notchmuse.com/appcast.xml` and `https://www.notchmuse.com/appcast.xml` against the staged bytes; confirm the enclosure URL, length, EdDSA signature, build and notes. Publish notes before atomically replacing the feed, retaining a rollback copy outside the served root. Source push alone does not deploy the manual origin.

Use the accepted, already-public frozen DMG; do not rebuild or replace it to enable update delivery. Existing Stable47/61 share the official feed and public key. Automatic checking follows user preference and schedule; installation is consented, not forced. Preview and Beta 3 or earlier are not reached by this stable feed. For a temporary same-ID test, back up preferences, ensure no Stable instance runs, copy the old app physically into a separate temporary directory, verify install/relaunch stays there, then quit the test copy and restore and compare the complete original preferences. `defaults import` merges keys: remove test-added keys when restoring and verify equality.
