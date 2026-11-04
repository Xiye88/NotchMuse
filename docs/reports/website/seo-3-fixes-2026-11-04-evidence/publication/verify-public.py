from pathlib import Path
import subprocess,json,hashlib,concurrent.futures,datetime,time,re,sys
root=Path(__file__).parent;m=json.loads((root/'source-manifest.json').read_text());b=json.loads((root/'server-before.json').read_text());source=root/'source/website';out=root/'public';out.mkdir(exist_ok=True)
protected={p:h for p,h in b['files'].items() if p not in m['files']};expect={**m['files'],**protected}
pages=['/','/zh/']+[p for s in ['spotify-lyrics-mac','menu-bar-lyrics','apple-music-desktop-lyrics-mac','macbook-notch-lyrics','lyricsx-alternative'] for p in ['/'+s+'/', '/zh/'+s+'/']]
# Full source manifest including assets; additionally canonical directory routes and www page routes.
targets=[('notchmuse.com','/'+p,h) for p,h in expect.items()]+[(host,p,m['files'][p.lstrip('/')+'index.html']) for host in ['notchmuse.com','www.notchmuse.com'] for p in pages]+[('www.notchmuse.com','/sitemap.xml',m['files']['sitemap.xml']),('www.notchmuse.com','/robots.txt',m['files']['robots.txt'])]
previous=json.loads((root/'public-verification.json').read_text()) if (root/'public-verification.json').exists() else {'results':[]}
old={(r['host'],r['path']):r for r in previous['results']}
def fetch(target):
 host,path,expected=target
 if (host,path) in old and old[(host,path)].get('pass'):return old[(host,path)]
 name=host+'-'+(path.strip('/').replace('/','_') or 'home');dest=out/(name+'.body');header=out/(name+'.headers');attempts=old.get((host,path),{}).get('attempts',[])
 for attempt in range(2):
  r=subprocess.run(['curl','-L','--connect-timeout','10','--max-time','30','-sS','-w','%{http_code}','-D',str(header),'https://'+host+path,'-o',str(dest)],capture_output=True,text=True)
  item={'exitCode':r.returncode,'status':r.stdout,'error':r.stderr,'attempt':len(attempts)+1};attempts.append(item)
  if r.returncode==0 and r.stdout=='200':
   data=dest.read_bytes();actual=hashlib.sha256(data).hexdigest();item['sha256']=actual
   # No transformations allowed by default: actual byte equality is tested.
   csp=re.findall(r'(?im)^content-security-policy:\s*([^\r\n]+)',header.read_text())
   return {'host':host,'path':path,'expectedSha256':expected,'actualSha256':actual,'pass':actual==expected,'status':200,'comparison':'EXACT_BYTES','allowedDifferences':[],'bytes':len(data),'csp':csp,'attempts':attempts}
 return {'host':host,'path':path,'expectedSha256':expected,'pass':False,'attempts':attempts}
results=list(concurrent.futures.ThreadPoolExecutor(max_workers=5).map(fetch,targets))
record={'checkedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'sourceCommit':m['sourceCommit'],'websiteTree':m['websiteTree'],'results':results,'passCount':sum(r['pass'] for r in results),'total':len(results),'allPass':all(r['pass'] for r in results)}
(root/'public-verification.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({k:v for k,v in record.items() if k!='results'},indent=2));print('Incomplete/mismatch:',[(r['host'],r['path']) for r in results if not r['pass']])
if not record['allPass']:sys.exit(1)
