const {chromium,expect}=require('@playwright/test');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{pathToFileURL}=require('node:url');
(async()=>{
 const root=path.resolve(process.argv[2]||'artifacts');
 const files=fs.readdirSync(root,{recursive:true}).filter(n=>path.basename(n)==='focus-replay.html');assert.equal(files.length,1);
 const file=path.join(root,files[0]),dir=path.dirname(file),browser=await chromium.launch();
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto(pathToFileURL(file).href);
  const video=page.locator('#video');
  await expect.poll(()=>video.evaluate(v=>v.readyState>=1&&Number.isFinite(v.duration))).toBe(true);
  const model=JSON.parse(await page.locator('#model').textContent());
  assert.equal(model.cues.length,6,'Reference requires six matched focus candidates');
  await expect(page.locator('#actions button')).toHaveCount(6);
  await expect(page.locator('#chapters button')).toHaveCount(6);
  for(const [i,c] of model.cues.entries()){
   await page.locator('#actions button').nth(i).click();
   await expect.poll(()=>video.evaluate((v,t)=>Math.abs(v.currentTime-t),c.first_visible_pts_ms/1000)).toBeLessThan(0.06);
   await video.evaluate((v,t)=>v.currentTime=t,(c.first_visible_pts_ms+c.last_visible_pts_ms)/2000);
   await expect(page.locator('#actions .active')).toHaveCount(1);
   await expect(page.locator('#steps .active')).toHaveCount(1);
   await expect(page.locator('#caption')).toHaveText('Focus: '+c.label);
   await expect.poll(()=>video.evaluate(v=>new DOMMatrix(getComputedStyle(v).transform).a)).toBeGreaterThan(1);
  }
  await page.locator('#zoom').uncheck();
  await expect.poll(()=>video.evaluate(v=>new DOMMatrix(getComputedStyle(v).transform).a)).toBe(1);
  await page.locator('#zoom').check();
  await page.locator('#captions').uncheck();await expect(page.locator('#caption')).toHaveText('');
  await page.locator('#captions').check();
  await page.locator('#chapters button').first().click();
  const c=model.cues[0];await expect.poll(()=>video.evaluate((v,t)=>Math.abs(v.currentTime-t),c.first_visible_pts_ms/1000)).toBeLessThan(0.06);
  await video.evaluate(v=>v.currentTime=0);
  await expect(page.locator('#steps .active')).toHaveCount(0);
  await expect(page.locator('#caption')).toHaveText('');
  await page.locator('#play').click();
  await expect.poll(()=>video.evaluate(v=>v.currentTime)).toBeGreaterThan(0.1);
  await page.locator('#play').click();
  await video.evaluate((v,t)=>v.currentTime=t,(c.first_visible_pts_ms+c.last_visible_pts_ms)/2000);
  await expect(page.locator('#caption')).toHaveText('Focus: '+c.label);
  await page.screenshot({path:path.join(dir,'focus-replay-desktop.png')});
  await page.setViewportSize({width:390,height:844});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'Mobile overflow');
  await page.screenshot({path:path.join(dir,'focus-replay-mobile.png')});
  assert.deepEqual(errors,[]);
  for(const name of ['focus-captions.vtt','focus-chapters.vtt'])assert.equal((fs.readFileSync(path.join(dir,name),'utf8').match(/ --> /g)||[]).length,6);
  assert.deepEqual(await video.evaluate(v=>Array.from(v.textTracks).map(t=>({kind:t.kind,count:t.cues.length}))),[{kind:'captions',count:6},{kind:'chapters',count:6}]);
  console.log('Verified focus replay seek, active steps, zoom toggle, playback, captions, chapters, responsive layout.');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
