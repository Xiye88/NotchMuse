# Showcase media

Requires FFmpeg/FFprobe with H.264 and VP9 encoders, Python 3, and `cwebp`.
No source recordings are stored in Git. Keep the supplied originals outside the checkout.

```sh
python3 scripts/media/render_showcase.py \
  --notch-source "$HOME/Desktop/录制于 2026-10-04 11.32.12.mp4" \
  --status-source "$HOME/Desktop/export-1791084390538.mp4" \
  --work-dir "$HOME/Desktop/edit/notchmuse-showcase/render"
```

The explicit source ranges and native crops live in `render_showcase.py`.
Segments are encoded individually and concatenated without another H.264 encode.
The MP4s use 1280×720, faststart, H.264, 30 fps and no audio; WebM uses VP9.
GIFs use 960×540, 12 fps, a 128-color palette and Bayer dithering;
GIF timing rounds to centiseconds.
WebP posters are the exact first decoded frame. Display/Appearance Settings are
1040×762 crops of Source A at 11.8s and 20.0s.

Outputs:

- `website/assets/media/`: three MP4s, WebMs and WebP posters.
- `docs/assets/demos/github/`: three optimized GIFs.
- `docs/assets/screenshots/`: the two current Settings screenshots.
- Work directory: segment cache, concat manifests, PNG posters, and `edl.json`.

Round 2 preserves the entire 1920×1080 source frame for all demos. The website
and README use the same 16:9 framing, keeping the menu bar, desktop and Dock.
Notch uses the continuous Source A interval 8.00–16.50s: the real Display
Settings notch preview and the switch from top lyrics to above Dock stay visible.
Status Bar uses Source B 36.50–43.50s, a stable wide interval with no source zoom
hiding the menu bar. Appearance retains its original edit with full desktop
context so the bottom lyrics visibly sit above the Dock.

Source A does not capture the physical MacBook notch. Only the app's own real
notch preview is present; no hardware notch or app output is fabricated.
Product Owner direction or additional footage is needed to satisfy the literal
physical-notch requirement. General Settings is absent from both recordings;
the existing Display/Appearance screenshots are unchanged.
