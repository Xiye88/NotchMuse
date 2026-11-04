from pathlib import Path
import hashlib,json,tarfile,shutil,subprocess,urllib.request,re,time,datetime
base=Path('/opt/notchmuse-site');stage=base/'seo-3-fixes-20261104';manifest=json.loads((stage/'source-manifest.json').read_text());before=json.loads((stage/'server-before.json').read_text())
old=Path(before['currentRelease']);new=base/'releases/20261104-seo-9d1d50e';server=base/'site_server.py';backup=base/'site_server.before-seo-20261104-9d1d50e.py'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert manifest['sourceCommit']=='9d1d50e79698d989b1bf80d53a49e19e93f7440b'
assert sha(stage/'website.tar')=='d5a1393ab114721327e644c586f5d664f4cb11e3c6fa8e241adf2f55438245b7'
assert sha(server)==before['serverSha256'] and not new.exists() and not backup.exists()
for p,h in before['files'].items():assert sha(old/p)==h,p
protected={p:h for p,h in before['files'].items() if p not in manifest['files']}
assert set(protected)=={'appcast.xml','NotchMuse.md','releases/v0.8.1/RELEASE_NOTES.en.md','releases/v0.8.1/RELEASE_NOTES.zh-CN.md'}
new.mkdir(mode=0o755)
with tarfile.open(stage/'website.tar') as t:
 for member in t.getmembers():
  assert member.name in manifest['files'] and member.isfile() and not member.issym() and not member.islnk(),member.name
 t.extractall(new,filter='data')
for p,h in protected.items():
 (new/p).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(old/p,new/p)
for p in new.rglob('*'):p.chmod(0o755 if p.is_dir() else 0o644)
expected={**manifest['files'],**protected}
assert {p.relative_to(new).as_posix():sha(p) for p in new.rglob('*') if p.is_file()}==expected
original=server.read_text();changed=original.replace(str(old),str(new));assert changed!=original and changed.replace(str(new),str(old))==original
compile(changed,str(server),'exec');shutil.copy2(server,backup)
result={'status':'staged','sourceCommit':manifest['sourceCommit'],'websiteTree':manifest['websiteTree'],'release':str(new),'previousRelease':str(old),'serverBackup':str(backup),'protectedFiles':protected,'originFiles':[],'deployedAt':datetime.datetime.now(datetime.timezone.utc).isoformat()}
try:
 temporary=base/'site_server.py.seo-20261104.tmp';temporary.write_text(changed);temporary.chmod(server.stat().st_mode);temporary.replace(server)
 subprocess.run(['systemctl','restart','notchmuse-site.service'],check=True)
 subprocess.run(['systemctl','is-active','--quiet','notchmuse-site.service'],check=True)
 for attempt in range(30):
  try:urllib.request.urlopen('http://127.0.0.1:8789/',timeout=2).close();break
  except OSError:
   if attempt==29:raise
   time.sleep(.2)
 for p,h in expected.items():
  url='http://127.0.0.1:8789/'+p
  with urllib.request.urlopen(url,timeout=30) as response:
   data=response.read();actual=hashlib.sha256(data).hexdigest();csp=response.headers.get('Content-Security-Policy');assert response.status==200 and actual==h,(p,actual,h)
   assert csp==before['headers']['Content-Security-Policy'],p
   result['originFiles'].append({'path':p,'status':response.status,'sha256':actual,'matches':True,'csp':csp})
 for p in ['/','/zh/']:
  with urllib.request.urlopen('http://127.0.0.1:8789'+p,timeout=10) as response:assert response.status==200
 assert server.read_text().replace(str(new),str(old))==original
 result['status']='DEPLOYED / ORIGIN_VERIFIED';result['serverSha256']=sha(server);result['serverChange']='Only os.chdir release directory; CSP/cache/server behavior preserved'
except Exception as error:
 server.write_text(original);subprocess.run(['systemctl','restart','notchmuse-site.service'],check=True)
 result['status']='FAILED / ROLLED_BACK';result['error']=str(error);(stage/'deployment.json').write_text(json.dumps(result,indent=2)+'\n');raise
(stage/'deployment.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
