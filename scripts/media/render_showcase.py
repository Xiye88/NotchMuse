#!/usr/bin/env python3
"""Render the three silent demos from the two supplied recordings using FFmpeg."""
import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEMOS = {
    'notch': [('a', 3.0, 1.9, '810:180:555:0'),
              ('a', 9.1, 1.9, '810:180:555:0'),
              ('a', 13.0, 4.7, '810:180:555:900')],
    'status-bar': [('b', 6.4, 3.0, '720:160:780:0'),
                   ('b', 9.7, 1.0, '720:160:780:0'),
                   ('b', 10.95, 3.0, '720:160:600:0')],
    'appearance': [('a', 19.95, 1.0, '810:180:555:900'),
                   ('a', 17.0, 1.0, '810:180:555:900'),
                   ('a', 21.05, 1.0, '810:180:555:900'),
                   ('a', 18.05, 1.5, '810:180:555:900'),
                   ('a', 23.3, 1.5, '810:180:555:900')],
}


def ffmpeg(*args):
    subprocess.run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', *map(str, args)], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--notch-source', type=Path, required=True)
    parser.add_argument('--status-source', type=Path, required=True)
    parser.add_argument('--work-dir', type=Path, required=True)
    args = parser.parse_args()
    sources = {'a': args.notch_source.resolve(), 'b': args.status_source.resolve()}
    for path in sources.values():
        if not path.is_file():
            parser.error(f'Missing recording: {path}')
    work = args.work_dir.resolve()
    work.mkdir(parents=True, exist_ok=True)
    web = ROOT / 'website/assets/media'
    github = ROOT / 'docs/assets/demos/github'
    shots = ROOT / 'docs/assets/screenshots'
    for directory in (web, github, shots):
        directory.mkdir(parents=True, exist_ok=True)
    for name, ranges in DEMOS.items():
        parts = []
        for index, (source, start, duration, crop) in enumerate(ranges):
            part = work / f'{name}-{index}.mp4'
            ffmpeg('-ss', start, '-i', sources[source], '-t', duration, '-map', '0:v:0', '-an',
                   '-vf', f'crop={crop},scale=1080:240:flags=lanczos,fps=30,setsar=1', '-c:v', 'libx264', '-preset', 'slow',
                   '-crf', '18', '-pix_fmt', 'yuv420p', '-map_metadata', '-1', part)
            parts.append(part)
        # Relative names avoid absolute-path escaping in the concat manifest.
        manifest = work / f'{name}-concat.txt'
        manifest.write_text(''.join(f"file '{part.name}'\n" for part in parts))
        mp4 = web / f'{name}-demo.mp4'
        ffmpeg('-f', 'concat', '-safe', '1', '-i', manifest, '-an', '-c', 'copy',
               '-movflags', '+faststart', '-map_metadata', '-1', mp4)
        ffmpeg('-i', mp4, '-an', '-c:v', 'libvpx-vp9', '-b:v', '0', '-crf', '28',
               '-deadline', 'good', '-cpu-used', '2', '-pix_fmt', 'yuv420p', web / f'{name}-demo.webm')
        poster = work / f'{name}-poster.png'
        ffmpeg('-i', mp4, '-frames:v', '1', poster)
        subprocess.run(['cwebp', '-quiet', '-q', '90', str(poster), '-o',
                        str(web / f'{name}-poster.webp')], check=True)
        palette = work / f'{name}-palette.png'
        ffmpeg('-i', mp4, '-vf', 'fps=15,palettegen=stats_mode=diff', '-frames:v', '1', palette)
        ffmpeg('-i', mp4, '-i', palette, '-lavfi',
               'fps=15[x];[x][1:v]paletteuse=dither=sierra2_4a:diff_mode=rectangle',
               '-loop', '0', github / f'{name}-demo.gif')
        print(f'{name}: {sum(r[2] for r in ranges):g}s', flush=True)
    for name, time in [('display', 11.8), ('appearance', 20.0)]:
        ffmpeg('-ss', time, '-i', sources['a'], '-vf', 'crop=1040:762:836:136',
               '-frames:v', '1', shots / f'{name}-settings.png')
    (work / 'edl.json').write_text(json.dumps({'sources': {k: str(v) for k, v in sources.items()},
                                             'demos': DEMOS}, indent=2, ensure_ascii=False) + '\n')


if __name__ == '__main__':
    main()
