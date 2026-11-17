const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = __dirname;
const pages = ['', 'zh', ...['spotify-lyrics-mac','menu-bar-lyrics','apple-music-desktop-lyrics-mac','macbook-notch-lyrics','lyricsx-alternative'].flatMap(x=>[x,`zh/${x}`])];
for (const page of pages) {
  const html = fs.readFileSync(path.join(root,page,'index.html'),'utf8');
  const head = html.split('</head>')[0];
  assert.equal((head.match(/data-pvuv/g)||[]).length,1);
  assert(head.includes('type="text/plain" data-pvuv data-src="https://www.pvuv.ai/f.js" data-site="f9FFRntt" data-api="https://in.pvuv.ai"'));
  assert.equal((html.match(/data-download-placement=/g)||[]).length,3);
}
function run(choice) {
  const storage = new Map(choice ? [['notchmuse.analytics-consent',choice]] : []);
  const cookies = new Map([['_pv_id','test'],['_ga','test'],['unrelated','keep']]);
  const elements = new Map();
  const element = key => { if(!elements.has(key))elements.set(key,{hidden:true,addEventListener(t,fn){this[t]=fn;},focus(){}});return elements.get(key); };
  const appended = [];
  const document = {
    documentElement:{lang:'en'},
    querySelector(key){if(key==='script[data-pvuv]')return {dataset:{src:'https://www.pvuv.ai/f.js',site:'f9FFRntt',api:'https://in.pvuv.ai'}};return element(key);},
    querySelectorAll(key){return key==='[data-analytics-settings]'?[element(key)]:[];},
    createElement(){return {dataset:{},remove(){this.removed=true;}};},
    head:{appendChild(x){appended.push(x);}},addEventListener(){},
    get cookie(){return [...cookies].map(([k,v])=>`${k}=${v}`).join('; ');},
    set cookie(value){if(value.includes('Max-Age=0'))cookies.delete(value.split('=')[0]);}
  };
  let reloads=0;
  const window={addEventListener(){}};
  vm.runInNewContext(fs.readFileSync(path.join(root,'analytics.js'),'utf8'),{window,document,localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v),removeItem:k=>storage.delete(k)},location:{hostname:'notchmuse.com',reload(){reloads++;}},URL});
  return {appended,storage,cookies,reloads:()=>reloads,click:key=>element(key).click()};
}
for(const initial of [null,'denied']) {
  const t=run(initial);assert.equal(t.appended.length,0,'No trackers before consent or after refusal');
  t.click('[data-consent-accept]');
  assert.equal(t.appended.length,2);assert.equal(t.appended[1].src,'https://www.pvuv.ai/f.js');
  assert.deepEqual(t.appended[1].dataset,{site:'f9FFRntt',api:'https://in.pvuv.ai'});
  t.click('[data-consent-accept]');assert.equal(t.appended.length,2,'Load only once');
  t.storage.set('_pv_id','test');t.click('[data-consent-reject]');
  assert.equal(t.reloads(),1);assert.equal(t.storage.get('_pv_id'),undefined);assert.equal(t.storage.get('notchmuse.analytics-consent'),'denied');
  assert.deepEqual([...t.cookies.keys()],['unrelated']);assert(t.appended.every(x=>x.removed));
}
assert.equal(run('granted').appended.length,2,'Saved consent loads both');
console.log('PASS: 12 page registrations/download placements; both trackers gated; once-only loading; saved consent; withdrawal/reload; scoped cookie/storage cleanup');
