# Update and Release Preparation

This workflow prepares artifacts locally. It does not push, publish, or alter the website.

1. Build a Preview with `NOTCHMUSE_INSTALL_PREVIEW=1 ./scripts/build_preview.sh 41`. Verify its bundle ID is `app.notchmuse.mac.preview`, its update feed is disabled, and the existing stable app is unchanged.
2. After Preview acceptance, build the stable candidate from a committed SHA with `./scripts/build_release.sh 0.8.0 41`. Record `dist.noindex/SHA256SUMS` and `BUILD-INFO.txt`. Run `codesign --verify --deep --strict` and `hdiutil verify`.
3. Run `./scripts/prepare_appcast.sh`. Sparkle's official `generate_appcast` signs the DMG entry with the `notchmuse` EdDSA key in Keychain. Inspect `dist.noindex/appcast-staging/appcast.xml` and verify that its URL, version, build, file length, and signature match the release asset.
4. Obtain separate Product Owner approval before publication. Upload the exact staged DMG to the matching GitHub tag, verify its public download URL, then deploy the signed appcast to `https://notchmuse.com/appcast.xml` and switch website download to the same DMG. Confirm GitHub, appcast, and website checksums and URLs. Do not publish a Preview build.
5. If the asset or feed is wrong, stop promotion. Restore the previous website download and previous signed appcast; do not rewrite a published signed release asset in place. Prepare a higher build instead.

Staged update testing is not complete until a lower-build app downloads and installs a higher-build signed artifact from a non-public test feed, then restarts with the new version and retains settings. An ad-hoc signed candidate may still trigger Gatekeeper on other Macs. Do not claim seamless first-run installation without Developer ID notarization.
