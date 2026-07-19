# NotchMuse Roadmap

Last Updated: 2026-07-19

## Phase 1: Beta Release

Goal: Publish a high-quality GitHub Open Source Beta Release for NotchMuse.

Scope:
- Stable macOS AppKit app.
- Status Bar mode.
- Notch Mode.
- Settings.
- Multi-language UI.
- Multi-provider line-synchronized lyrics.
- DMG packaging.
- README, changelog, license, third-party notices.

Exit Criteria:
- GitHub Release package complete.
- Unsigned build documentation complete, including macOS security warning and Open Anyway flow.
- Clean build verification passed.
- Clean install QA passed for the GitHub beta DMG.
- Spotify permission flow verified.
- Accessibility permission flow verified.
- Status Bar and Notch Mode visually verified.
- GitHub Release notes and screenshots ready.
- Benchmark quality showcase ready.

Out of Scope:
- New providers.
- Fuzzy matching rollout.
- Intel support.
- Universal Binary.
- Windows.
- Dashboard UI.

Future Distribution Phase:
- Developer ID signed app.
- Apple notarization and stapling.
- Gatekeeper accepted without unsigned-app warning.

## Phase 2: Lyrics Quality Optimization

Goal: Establish a repeatable Benchmark to App optimization loop.

Loop:
1. Benchmark finds failed songs and failure reasons.
2. Benchmark generates optimization recommendations.
3. PM selects a small safe batch.
4. App matcher/provider logic changes only when risk is low.
5. Self-tests and live matrix validate the change.
6. Benchmark reruns and records coverage impact.

Initial Batches:
- Artist separator and alias parity.
- Safe title metadata normalization.
- Rejected candidate logging.
- One retry for transient provider failures.
- Benchmark-to-Swift matcher parity checklist.

Guardrails:
- Do not optimize coverage by increasing wrong matches.
- Do not relax live/remix/acoustic/instrumental version safety without evidence.
- Do not change provider strategy without latency and false-positive checks.

## Phase 3: Future Expansion

Candidates:
- Intel Mac support.
- Universal Binary.
- More providers.
- Better Benchmark dashboard.
- More polished website/demo assets.

Explicitly Deferred:
- Windows app.
- Accounts/cloud sync.
- AI-generated lyrics.
- App Store distribution.
