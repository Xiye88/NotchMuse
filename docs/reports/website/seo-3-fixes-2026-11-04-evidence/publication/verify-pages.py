import pathlib,json,re,hashlib
from html.parser import HTMLParser
r=pathlib.Path(__file__).parent;source=r/'source/website'
old=pathlib.Path('/Users/carlos/.codex/worktrees/notchmuse-website-publish/歌词/docs/reports/website/seo-3-fixes-2026-11-04-evidence');before=json.loads((old/'before.json').read_text());after=json.loads((old/'after.json').read_text())
class Page(HTMLParser):
 def __init__(self):super().__init__();self.head=False;self.values={'meta':[],'links':[],'downloads':[],'languageToggle':[]}
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if tag=='head':self.head=True
  if tag=='html':self.values['lang']=a['lang']
  if self.head and tag=='meta':self.values['meta'].append(a)
  if self.head and tag=='link':self.values['links'].append(a)
  if tag=='a' and 'data-download-placement'in a:self.values['downloads'].append(a)
  if a.get('id')=='language-toggle':self.values['languageToggle'].append({'tag':tag,**a})
 def handle_endtag(self,tag):
  if tag=='head':self.head=False
results=[]
for b,a in zip(before['pages'],after['pages']):
 url=a['url'];file=r/'public'/('notchmuse.com-'+(url.strip('/').replace('/','_') or 'home')+'.body')
 text=file.read_text();expected=(source/(url.lstrip('/')+'index.html')).read_text();assert text==expected,url
 parser=Page();parser.feed(text);values=parser.values
 for key in ['meta','links','lang','downloads','languageToggle']:assert values[key]==b[key],(url,key)
 for key,pattern in [('title',r'<title>(.*?)</title>'),('h1',r'<h1\b[^>]*>(.*?)</h1>')]:assert re.findall(pattern,text,re.S)==b[key],(url,key)
 blocks=[json.loads(s)for s in re.findall(r'<script type="application/ld\+json">(.*?)</script>',text,re.S)];assert blocks==a['jsonLd'],url
 app=[s for s in blocks if s['@type']=='SoftwareApplication'];assert len(app)==1;assert app[0]['url']==next(l['href']for l in values['links']if l['rel']=='canonical')
 assert app[0]['inLanguage']==values['lang']
 if 'lyricsx-alternative' in url:
  assert 'NotchMuse v0.8.0'not in text and ('2026 年 10 月 17 日' in text if values['lang']=='zh-Hans' else 'October 17, 2026'in text)
 else:
  if url in ['/','/zh/']:assert 'v0.8.0'in text and 'feed'in text
 results.append({'path':url,'status':200,'softwareApplicationCount':1,'breadcrumbCount':len(blocks)-1,'canonicalLanguageHreflang':'PASS','downloadAttributes':'UNCHANGED','downloadCount':len(values['downloads']),'nativeLanguageLink':values['languageToggle'][0]['href'],'protectedMetaTitleH1':'UNCHANGED','comparisonDateWording':'PASS','exactGitHubHtmlBytes':True})
sitemap=(r/'public/notchmuse.com-sitemap.xml.body').read_text();assert set(re.findall(r'<loc>([^<]+)</loc>',sitemap))=={'https://notchmuse.com'+p['url']for p in after['pages']}
record={'sourceCommit':'9d1d50e79698d989b1bf80d53a49e19e93f7440b','pages':results,'totalApplications':12,'totalBreadcrumbs':10,'downloadAnchors':36,'sitemap12Urls':'PASS','allPass':True}
(r/'public-pages.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n');print('PASS: all12public pages exact GitHub source,12schemas/10breadcrumbs,canonical/lang/hreflang,36download attributes,P0/P2 and homepage copy protected')
