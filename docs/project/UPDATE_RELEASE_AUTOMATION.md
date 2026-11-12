# Update and release execution

Use [RELEASE_CHECKLIST](RELEASE_CHECKLIST.md) for every release. Record VERSION,
BUILD, SOURCE_SHA and frozen artifact paths for that release; examples below are
parameters, not old release numbers to reuse. One Product Owner release approval
covers the entire publication sequence; do not split approval by channel.

1. Develop/test isolated Preview. Obtain Preview acceptance, prepare and verify the Stable candidate from recorded source. Keep Stable/Preview identity separate. Run applicable tests/CI, signature/mount/install/self-test checks and record SHA256/length/provenance. Preserve previous artifact/settings rollback.
2. Prepare both READMEs, CHANGELOG, Release body, current features/install instructions, complete bilingual notes and all website pages/download/JSON-LD. Review real screenshots/GIFs and About metadata. Preserve SEO/canonical/hreflang/GA4/GSC/CSP/download-placement. Run `python3 scripts/check_release_consistency.py "$VERSION" "$BUILD"` against staged release metadata.
3. Stage appcast using `scripts/prepare_appcast.sh "$APP" "$DMG" "$BILINGUAL_NOTES" "$OUTPUT_XML"`. Explicitly pass complete combined bilingual notes; do not use an English-only default. Inspect build/version/URL/length/signatures. Test lower-build install/relaunch and applicable failure recovery using a private feed before promotion.
4. Obtain one final Product Owner authorization for this formal release. Push source, require CI success, create matching tag/regular GitHub Release and upload the exact frozen package/checksums/build info/bilingual notes. Verify anonymous public download bytes. Never rewrite a published signed package in place.
5. Back up the production site/feed outside served paths. Deploy versioned notes first at `/releases/v$VERSION/NotchMuse.md` (and linked language files), verify public loading, then atomically promote signed appcast. Do not advertise an asset before it exists.
6. Deploy matching website pages/downloads to the existing origin; preserve security and growth configuration. Source push alone does not deploy the site. Verify origin files and real apex/www responses. Inspect GitHub About through its API, not source text.
7. Run `python3 scripts/check_release_consistency.py "$VERSION" "$BUILD" --online`. Verify actual updater popup notes, lower-client discovery/install/relaunch, public package hashes, Latest and CI. Restore previous feed/site if a material delivery failure occurs; do not announce completion with a stale feed.
8. Update canonical status/handoff with source, version/Build, deployed/verified/untested and recovery location. Do not duplicate the full checklist in each PM document.

## Boundaries

Pause for safety risk, major failed tests or scope beyond approval; do not skip
critical checks to meet one-pass delivery. Developer ID/notarization and clean-Mac
coverage must be reported accurately. Automatic checks and automatic installation
are distinct user preferences. Beta3/earlier require one manual install.

Temporary same-ID tests share preferences: back them up, confirm no other instance,
use a full physical temporary app copy, verify actual install/relaunch path, quit it,
restore the exact preference dictionary and compare (defaults import merges).
Never export signing keys. Keep production keys in Keychain/protected environment.
