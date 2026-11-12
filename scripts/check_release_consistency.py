#!/usr/bin/env python3
"""Check staged release references; --online additionally reads actual delivery endpoints.
Does not verify EdDSA cryptography, UI, installer/relaunch, media truth or feature parity.
"""
import argparse, hashlib, json, re, subprocess, urllib.request
from pathlib import Path
import xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parents[1]

def validate(root, version, build):
    asset = f'https://github.com/Xiye88/NotchMuse/releases/download/v{version}/NotchMuse.dmg'
    for name in ['README.md', 'README.zh-CN.md', 'CHANGELOG.md']:
        text = (root/name).read_text()
        assert version in text, f'{name}: version missing'
        if name != 'CHANGELOG.md': assert asset in text, f'{name}: download missing'
    pages = sorted((root/'website').rglob('*.html'))
    assert len(pages) >= 12, 'website page inventory incomplete'
    for page in pages:
        text = page.read_text()
        links = re.findall(r'https://github\.com/Xiye88/NotchMuse/releases/download/[^"\s<>]+', text)
        assert links and all(link == asset for link in links), f'{page}: stale download'
        blocks = re.findall(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', text, re.S)
        apps = []
        def walk(value):
            if isinstance(value, dict):
                if value.get('@type') == 'SoftwareApplication': apps.append(value)
                for child in value.values(): walk(child)
            elif isinstance(value, list):
                for child in value: walk(child)
        for block in blocks: walk(json.loads(block))
        assert apps and all(a.get('downloadUrl') == asset for a in apps), f'{page}: structured download'
        assert 'canonical' in text and 'hreflang' in text and 'data-download-placement' in text, f'{page}: SEO/download hooks missing'
    feed = root/f'docs/releases/v{version}/appcast.xml'
    ns = {'s':'http://www.andymatuschak.org/xml-namespaces/sparkle'}
    items = ET.fromstring(feed.read_bytes()).findall('./channel/item')
    item = next((i for i in items if i.findtext('s:version', namespaces=ns)==build), None)
    assert item is not None and item.findtext('s:shortVersionString', namespaces=ns)==version, 'feed build/version'
    enclosure = item.find('enclosure')
    assert enclosure.get('url')==asset and int(enclosure.get('length','0'))>0, 'feed asset/length'
    assert enclosure.get('{'+ns['s']+'}edSignature'), 'archive signature missing'
    notes = item.findtext('s:releaseNotesLink', namespaces=ns)
    assert notes == f'https://notchmuse.com/releases/v{version}/NotchMuse.md', 'versioned notes URL'
    content=(root/f'docs/releases/v{version}/NotchMuse.md').read_text()
    assert '简体中文' in content and re.search('[A-Za-z]{5}',content), 'combined bilingual notes missing'
    return asset, enclosure, pages

def fetch(url):
    return subprocess.check_output(['curl','-q','-fsSL','--max-time','40',url])

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('version');p.add_argument('build');p.add_argument('--online',action='store_true');a=p.parse_args()
    asset,enclosure,pages=validate(ROOT,a.version,a.build)
    print(f'PASS local: {len(pages)} pages, README, CHANGELOG, JSON-LD, feed metadata and combined notes')
    if a.online:
        release=json.loads(subprocess.check_output(['gh','api','repos/Xiye88/NotchMuse/releases/latest']))
        assert release['tag_name']=='v'+a.version and not release['prerelease'] and not release['draft'], 'Latest mismatch'
        assets={x['name']:x for x in release['assets']};assert assets['NotchMuse.dmg']['size']==int(enclosure.get('length'))
        data=fetch(asset);digest=hashlib.sha256(data).hexdigest()
        assert len(data)==int(enclosure.get('length')) and digest in fetch(assets['SHA256SUMS']['browser_download_url']).decode(), 'public checksum'
        about=json.loads(subprocess.check_output(['gh','api','repos/Xiye88/NotchMuse']))['description'] or ''
        assert not re.search(r'v\d+\.\d+\.\d+',about), 'About contains fixed version'
        for host in ['notchmuse.com','www.notchmuse.com']:
            assert fetch('https://'+host+'/appcast.xml')==(ROOT/f'docs/releases/v{a.version}/appcast.xml').read_bytes(), 'public feed differs'
            assert fetch(f'https://{host}/releases/v{a.version}/NotchMuse.md')==(ROOT/f'docs/releases/v{a.version}/NotchMuse.md').read_bytes(), 'public notes differ'
            for page in pages:
                rel=str(page.relative_to(ROOT/'website'))
                assert fetch('https://'+host+'/'+rel)==page.read_bytes(), f'public page differs: {host}/{rel}'
        print('PASS online: Latest, About, package checksum, apex/www pages, actual feed and notes')
if __name__=='__main__': main()
