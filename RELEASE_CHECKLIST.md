# NotchMuse Beta Release Checklist

## Product

- [ ] Core features tested
- [ ] Settings tested
- [ ] Spotify tested with real playback
- [ ] Status Bar only exposes Left and Right
- [ ] Settings hides inactive Display Mode controls
- [ ] Lyrics Width and Display Screen naming reviewed

## macOS

- [ ] Accessibility permission tested from a clean install
- [ ] Apple Events permission tested from a clean install
- [ ] Repeated Display Mode and Position changes do not loop permission prompts
- [ ] Repeated launch tested with `open -n`
- [ ] Quit and restart leave one NotchMuse process
- [ ] Unsigned beta Gatekeeper warning is documented and expected
- [ ] Control-click Open flow tested
- [ ] System Settings > Privacy & Security > Open Anyway flow tested

## Packaging

- [ ] Version set to `0.3.1`
- [ ] Build number set to `4`
- [ ] Bundle Identifier is `app.notchmuse.mac`
- [ ] `./scripts/build_release.sh 0.3.1 4` completed
- [ ] DMG opens and supports drag-to-Applications installation
- [ ] DMG verifies with `hdiutil verify`
- [ ] README reviewed
- [ ] CHANGELOG reviewed

## GitHub

- [ ] Release notes prepared from CHANGELOG
- [ ] Status Bar screenshot added
- [ ] Notch Mode screenshot added
- [ ] Settings screenshot added
- [ ] Status Bar and Notch Mode demo videos added
- [ ] `NotchMuse.dmg` uploaded
- [ ] Published as a Beta/pre-release
