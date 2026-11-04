import json,subprocess,hashlib,concurrent.futures,datetime
from pathlib import Path
base=Path('/opt/notchmuse-site/seo-3-fixes-20261104');m=json.loads((base/'source-manifest.json').read_text());paths=['assets/demos/notch-mode.gif','assets/demos/status-bar.gif','assets/mac-desktop.png','assets/media/appearance-demo.mp4','assets/media/appearance-demo.webm','assets/media/notch-demo.mp4']
def get(p):
 dest=base/('public-'+p.replace('/','_'));r=subprocess.run(['curl','-L','--connect-timeout','10','--max-time','30','-sS','-w','%{http_code}','https://notchmuse.com/'+p,'-o',str(dest)],capture_output=True,text=True)
 h=hashlib.sha256(dest.read_bytes()).hexdigest()if r.returncode==0 else None
 return {'host':'notchmuse.com','path':'/'+p,'status':r.stdout,'exitCode':r.returncode,'sha256':h,'expectedSha256':m['files'][p],'pass':r.returncode==0 and r.stdout=='200'and h==m['files'][p],'error':r.stderr,'vantage':'production host -> public Cloudflare HTTPS (not localhost)'}
results=list(concurrent.futures.ThreadPoolExecutor(max_workers=3).map(get,paths));print(json.dumps({'checkedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'results':results,'allPass':all(x['pass']for x in results)},indent=2))
