const {chromium}=require('playwright');
const fs=require('node:fs');const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.PLAYWRIGHT_EXECUTABLE_PATH});
 const previous=JSON.parse(fs.readFileSync(__dirname+'/public-browser.json','utf8'));
 const results=[];
 try{
  for(const [suffix,name] of [['/','home-en'],['/zh/','home-zh'],['/lyricsx-alternative/','lyricsx-en'],['/zh/lyricsx-alternative/','lyricsx-zh']]){
   const prior=previous.results.find(item=>item.path===suffix);
   if(prior?.result==='PASS'){results.push(prior);continue;}
   const context=await browser.newContext({reducedMotion:'reduce',viewport:{width:1440,height:1000}});
   let google=0;let interceptedDownloads=0;
   await context.route(/https:\/\/[^/]*(?:google-analytics|googletagmanager|analytics\.google)\.com\//,route=>{google++;return route.abort();});
   await context.route('**/NotchMuse.dmg',route=>{interceptedDownloads++;return route.fulfill({contentType:'application/octet-stream',headers:{'Content-Disposition':'attachment; filename="navigation-test.txt"'},body:'Public download navigation test; real DMG not downloaded'});});
   const page=await context.newPage();let entry={path:suffix};
   try{
    const response=await page.goto('https://notchmuse.com'+suffix+'?verify=seo-9d1d50e',{waitUntil:'domcontentloaded',timeout:30000});assert.equal(response.status(),200);
    assert.equal(await page.locator('head script[type="application/ld+json"]').evaluateAll(nodes=>nodes.map(n=>JSON.parse(n.textContent)).filter(n=>n['@type']==='SoftwareApplication').length),1);
    assert.equal(await page.locator('a[data-download-placement]').count(),3);
    await page.locator('h1').waitFor({state:'visible'});
    await page.waitForFunction(()=>[...document.querySelectorAll('link[rel=stylesheet]')].every(link=>!!link.sheet));
    await page.screenshot({path:__dirname+'/public-'+name+'.png'});
    for(const placement of ['nav','hero','footer']) await Promise.all([page.waitForEvent('download'),page.locator(`a[data-download-placement="${placement}"]`).click()]);
    assert.equal(interceptedDownloads,3);assert.equal(google,0);
    entry={...entry,previousAttempt:prior,status:200,visualScreenshot:'public-'+name+'.png',threeNativeDownloadNavigations:'PASS (intercepted)',googleRequests:google,result:'PASS'};
   }catch(error){entry={...entry,previousAttempt:prior,result:'INCONCLUSIVE',error:String(error)};}
   results.push(entry);await context.close();
  }
 }finally{await browser.close();fs.writeFileSync(__dirname+'/public-browser.json',JSON.stringify({results},null,2)+'\n');console.log(JSON.stringify(results,null,2));}
})().catch(e=>{console.error(e);process.exitCode=1;});
