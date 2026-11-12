# Standard release checklist

Copy the unchecked checklist into the release evidence and record target version,
Build, source SHA, artifact SHA256, authorization and result/evidence per item.
Never inherit checks from an older release. Historical completed0.8.0 checklist:
[archive](../archive/RELEASE_CHECKLIST-v0.8.0-completed.md).

## Candidate and authorization
- [ ] Product Owner accepts Preview and authorizes this formal release once.
- [ ] Required tests/CI pass at the source SHA; document untested cases and accepted limits.
- [ ] Version/Build, Stable identity, signed package, mount/install/self-test and checksums verified; Preview remains separate.
- [ ] Retain previous artifact, feed, site and settings recovery procedure; test applicable failure paths.

## GitHub
- [ ] EN/ZH README version, download URLs, features and installation instructions agree.
- [ ] CHANGELOG describes this release; Release version/Build, DMG, checksums/build info and equally detailed bilingual notes agree.
- [ ] Actual repository About metadata checked and corrected if stale.
- [ ] Screenshots/GIFs reviewed against functionality. Historical captures retain truthful version labels; replace only with genuine new captures.
- [ ] Latest regular Release/tag/source and public downloaded bytes/checksum verified.

## Website
- [ ] EN/ZH home and all existing product pages checked (currently12 pages).
- [ ] Every download CTA and SoftwareApplication JSON-LD URL targets the exact released package.
- [ ] Relevant new features, installation instructions, automatic-update FAQ and EN/ZH parity reviewed.
- [ ] SEO, canonical, hreflang, GA4, GSC, CSP and data-download-placement preserved.
- [ ] Deploy actual website origin; Git push is not deployment. Verify apex/www pages and downloads publicly.

## Sparkle
- [ ] Publish complete English-first/Chinese-second notes before feed; actual popup loads both sections.
- [ ] appcast version/Build, URL, length and EdDSA archive/feed signatures verified against released artifact and embedded key.
- [ ] Lower-version discovery/download/install/relaunch verified with settings and identity retained.
- [ ] Production apex/www real appcast bytes and notes verified, not just local source.
- [ ] Previous feed/package/site rollback retained; failure recovery status stated.

## Completion
- [ ] GitHub Latest, both READMEs, website and Sparkle agree on version/Build and artifact.
- [ ] Public package downloads and checksum agree; EN/ZH entry points function.
- [ ] Run scripts/check_release_consistency.py VERSION BUILD; run --online after deployment. Review its limits; it does not replace installer/UI/signature tests.
- [ ] Final delivery reports deployed, verified and untested separately. No automatic-update completion claim based solely on GitHub Release publication.
