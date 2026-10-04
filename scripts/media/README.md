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
The MP4s use faststart, H.264, 30 fps and no audio; WebM uses VP9.
GIFs use 15 fps with `palettegen` and `paletteuse`; GIF timing rounds to centiseconds.
WebP posters are the exact first decoded frame. Display/Appearance Settings are
1040×762 crops of Source A at 11.8s and 20.0s.

Outputs:

- `website/assets/media/`: three MP4s, WebMs and WebP posters.
- `docs/assets/demos/github/`: three optimized GIFs.
- `docs/assets/screenshots/`: the two current Settings screenshots.
- Work directory: segment cache, concat manifests, PNG posters, and `edl.json`.

A full desktop crop was avoided so that the lyrics remain readable. Source A
shows the top and above-Dock overlay positions; the physical screen notch is not
captured. Source B already contains zooms. Those limitations are retained rather
than reconstructing app output. General Settings is absent from both recordings;
the obsolete Settings screenshot is not reused.
