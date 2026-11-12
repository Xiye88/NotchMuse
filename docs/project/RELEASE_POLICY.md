# Release Policy

- `/Applications/NotchMuse.app` is the stable installation. `/Applications/NotchMuse Preview.app` has a separate bundle ID and preferences and is never distributed publicly.
- Build numbers increase across candidates. Preview builds do not replace the installed stable app.
- A public release needs Product Owner Preview acceptance, build and self-test results, player and Settings checks, a verified DMG, and an explicit publication decision.
- Publish a release atomically: tag and GitHub Release with the DMG, matching signed `appcast.xml`, website download link, release notes, and checksum. Verify each public URL before announcing it. Do not publish the feed ahead of its asset.
- Sparkle checks are optional and user-controlled. Updates require an EdDSA signature. The private key remains in the macOS Keychain or a protected release environment; only the public key belongs in the app.
- Beta 3 and earlier lack Sparkle. They cannot update themselves and require a one-time manual install of v0.8.0 or later.
- Current ad-hoc signing is not notarization. Keep Gatekeeper instructions visible; never suggest disabling system-wide security. Developer ID signing and notarization are a separate future decision.

See [UPDATE_RELEASE_AUTOMATION.md](UPDATE_RELEASE_AUTOMATION.md) for commands and rollback checks.

## Permanent owner preference — release communication (2026-11-10)

- Every future release must have complete English and Simplified Chinese notes of equal detail: the same features, fixes, examples and material limits in both languages. Do not reduce Chinese to a short summary of the English.
- Begin with a short overview of what changed and a visible language cue such as “English first · 中文说明在下方”. Put the complete English section first and the complete Chinese section below it.
- Apply this rule to the actual in-app update notes, GitHub Release body and website release notes. Checking a separate Chinese file is insufficient if the app's feed points to an English-only file or abbreviated Chinese. The current prepare_appcast default uses English input; next-release preparation must use a combined bilingual input and review the actual popup.
- Explain concrete user-visible outcomes and before/after behavior; avoid vague improvement claims or unnecessary implementation terms.
- Owner accepts the existing v0.8.2 notes as-is. This preference applies from the next release; do not retroactively rewrite or redeploy the current notes under this instruction.

## Next-version requirement — startup updates (recorded, not implemented)

Owner requests checking for new versions when the app is opened, plus a separate automatic-update checkbox, default ON for an unset preference as explicitly requested in the later implementation instruction. Startup checking should discover and show a new release without requiring a manual Check for Updates action, while respecting the user's update preferences. When automatic updating is enabled, the next opening after a new release should automatically fetch, verify and install the update, with a clear indication of any restart or authorization still needed. A check-only switch is not sufficient. Use the existing signed Stable update chain, preserve Preview separation and the working old version on failure; never report success before install/relaunch verification. Offline launches should leave the app usable. Final startup/restart behavior and failure recovery require candidate validation before publication.

Current v0.8.2 still uses scheduled checks and consented installation. Existing old clients need to upgrade into the future release before they can gain the new startup/automatic-install behavior; server-side feed promotion cannot rewrite old client behavior.

Implementation clarification (owner, same day): startup no-update checks must be silent; automatic updating defaults ON for new/unset preferences and preserves explicit OFF; long-running clients also need periodic checks. PM selects86400 seconds using Sparkle scheduling. Startup automatic mode may install/relaunch; running sessions download then show a ready-to-install reminder instead of unexpectedly restarting during use. This is local Preview development only.

## Unified authorization — owner instruction2026-11-12

Each App formal release requires one Product Owner publication authorization.
Once granted for that release it covers related Git push, tag/Release/assets,
website deployment, complete bilingual notes, Sparkle promotion and final public
verification. Do not request per-channel confirmations. It does not authorize a
later App release. Confirmed routine website/SEO changes include implementation,
tests, GitHub sync, deployment and public verification. Pause for material safety
risks, major failed tests or work beyond scope; never bypass key verification.
The standard RELEASE_CHECKLIST.md replaces the historical completed0.8.0 list;
UPDATE_RELEASE_AUTOMATION.md defines deployment order. These rules supersede
older historical instructions requesting separate source/website/feed approvals.
