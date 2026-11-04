import pathlib, re, json, hashlib, sys, subprocess
from html.parser import HTMLParser
ROOT=pathlib.Path('/Users/carlos/.codex/worktrees/notchmuse-website-publish/歌词')
OUT=pathlib.Path(__file__).resolve().parent
BASE='9a4220703a7ee397f626d8972e3549a618a2acb6'
class Page(HTMLParser):
 def __init__(self):
  super().__init__(); self.head=False; self.values={'meta':[], 'links':[], 'downloads':[], 'languageToggle':[]}
 def handle_starttag(self, tag, attrs):
  a=dict(attrs)
  if tag=='head': self.head=True
  if tag=='html': self.values['lang']=a['lang']
  if self.head and tag=='meta': self.values['meta'].append(a)
  if self.head and tag=='link': self.values['links'].append(a)
  if tag=='a' and 'data-download-placement' in a:self.values['downloads'].append(a)
  if a.get('id')=='language-toggle':self.values['languageToggle'].append({'tag':tag,**a})
 def handle_endtag(self,tag):
  if tag=='head': self.head=False

def sha(data):return hashlib.sha256(data).hexdigest()
pages=[]; inventory=[]
paths=['/','/zh/']+[p for s in ['spotify-lyrics-mac','menu-bar-lyrics','apple-music-desktop-lyrics-mac','macbook-notch-lyrics','lyricsx-alternative'] for p in ['/'+s+'/', '/zh/'+s+'/']]
for url in paths:
 file='website/'+url.lstrip('/')+'index.html'
 raw=(ROOT/file).read_bytes(); text=raw.decode(); parsed=Page();parsed.feed(text)
 values=parsed.values
 for name, pattern in [('title',r'<title>(.*?)</title>'),('h1',r'<h1\b[^>]*>(.*?)</h1>')]:values[name]=re.findall(pattern,text,re.S)
 values['jsonLd']=[json.loads(x) for x in re.findall(r'<script type="application/ld\+json">(.*?)</script>',text,re.S)]
 values['url']=url;values['file']=file;values['sha256']=sha(raw)
 pages.append(values)
 for match in re.finditer(r'<p\b[^>]*>(.*?)</p>',text,re.S):
  plain=re.sub('<[^>]+>','',match[1])
  if re.search('Reviewed|reviewed|核对|v0.8.0',plain):
   inventory.append({'url':url,'file':file,'line':text[:match.start()].count('\n')+1,'original':plain,'action':'Remove only fixed NotchMuse version from comparison statement; retain historical date and limitations' if 'v0.8.0' in plain and 'lyricsx-alternative' in url else 'KEEP: factual update-feed statement' if 'v0.8.0' in plain else 'KEEP: historical documentation review date' if '2026' in plain else 'KEEP: existing navigation wording; not a dated review claim'})
result={'base':BASE,'pages':pages,'p0Inventory':inventory,'protectedFiles':{p:sha((ROOT/p).read_bytes()) for p in ['website/analytics.js','website/showcase.js','website/style.css','website/guides.css','website/sitemap.xml','website/robots.txt']}}
(OUT/(sys.argv[1]+'.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
if sys.argv[1]=='after':
 before=json.loads((OUT/'before.json').read_text())
 checks=[]
 for old,new in zip(before['pages'],pages):
  for key in ['lang','meta','links','downloads','languageToggle','title','h1']:
   assert old[key]==new[key],(new['file'],key)
  assert old['jsonLd']==[o for o in new['jsonLd'] if o['@type']!='SoftwareApplication']
  original=subprocess.check_output(['git','show',BASE+':'+new['file']],cwd=ROOT).decode()
  current=(ROOT/new['file']).read_text()
  current=re.sub(r'  <script type="application/ld\+json">\n\{.*?\n\}\n  </script>\n','',current,flags=re.S)
  expected=original.replace('Reviewed October 17, 2026 using the public NotchMuse v0.8.0 site and LyricsX project documentation.','Documentation reviewed October 17, 2026, using the publicly available NotchMuse website and LyricsX project documentation.').replace('2026 年 10 月 17 日核对 NotchMuse v0.8.0 公开官网和 LyricsX 项目文档。','2026 年 10 月 17 日核对了 NotchMuse 公开官网及 LyricsX 项目文档。')
  assert current==expected,new['file']
  checks.append({'file':new['file'],'protectedFields':'PASS','exactHtmlOutsideAuthorizedChanges':'PASS','softwareApplicationCount':len(new['jsonLd'])-len(old['jsonLd']),'breadcrumbCount':len(old['jsonLd'])})
 assert before['protectedFiles']==result['protectedFiles']
 (OUT/'protection.json').write_text(json.dumps({'pages':checks,'protectedFiles':'UNCHANGED','downloadAnchors':sum(len(p['downloads']) for p in pages)},indent=2)+'\n')
print(f'{sys.argv[1]}: {len(pages)} pages; {len(inventory)} date/version statements')
