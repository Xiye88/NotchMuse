# v0.8.1 / Build61

- [English release notes](RELEASE_NOTES.en.md) · [中文发布说明](RELEASE_NOTES.zh-CN.md)
- [Frozen source provenance](SOURCE_PROVENANCE.json) · [Verification summary](VERIFICATION_SUMMARY.json)
- Production identity: `app.notchmuse.mac`, macOS14+, arm64, ad-hoc signed, not notarized.
- The original frozen DMG is unchanged. Its original build commit is recorded in provenance; the public `v0.8.1` tag contains byte-identical runtime and packaging inputs. Private development history and user-state evidence are not published.
- Explicit rebuild command: `./scripts/build_release.sh 0.8.1 61`. Rebuilding is not a claim of byte-for-byte binary reproducibility.
- Manual installation for this release; official Sparkle feed remains Build47 pending actual isolated installer/relaunch/recovery verification. The valid archive signature is not used to bypass that gate.
- Existing 474 automated checks and 15 packaged production-contract checks passed. Full XCTest is not reported as passed; independent clean-Mac first installation is NOT_TESTED.
