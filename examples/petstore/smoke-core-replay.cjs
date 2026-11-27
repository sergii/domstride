// Verify the production Replay template via the actual Ruby Report exporter.
const {chromium,expect}=require('@playwright/test');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{pathToFileURL}=require('node:url');
(async()=>{
 const root=path.resolve(process.argv[2]||'artifacts'),files=fs.readdirSync(root,{recursive:true}).filter(n=>path.basename(n)==='core-replay.html');
 assert.equal(files.length,1);
 const file=path.join(root,files[0]),browser=await chromium.launch();
 try{
 const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 await page.goto(pathToFileURL(file).href);
 const data=JSON.parse(await page.locator('#recording-data').textContent());
 const idx=data.cases.findIndex(c=>c.videos.some(v=>v.timing_quality==='visual_candidates_unvalidated'));assert.ok(idx>=0);
 await expect(page.locator('#case-select')).toHaveValue(String(idx));
 await expect(page.locator('#video-evidence')).toBeVisible();
 await expect(page.locator('#no-evidence')).toBeHidden();
 const video=page.locator('#browser-video'),segments=data.cases[idx].videos[0].focus;assert.equal(segments.length,6);
 await expect.poll(()=>video.evaluate(v=>v.readyState>=1&&Number.isFinite(v.duration))).toBe(true);
 await page.locator('#focus-speed').selectOption('0');
 await expect(page.locator('#focus-highlight')).toBeDisabled();
 assert.deepEqual(await video.evaluate(v=>Array.from(v.textTracks).map(t=>({kind:t.kind,count:t.cues.length}))),[{kind:'captions',count:6},{kind:'chapters',count:6}]);
 for(const [i,s] of segments.entries()){
   await page.locator('#observed-actions button').nth(i).click();
   await expect.poll(()=>video.evaluate((v,t)=>Math.abs(v.currentTime-t),s.start_ms/1000)).toBeLessThan(0.06);
   await video.evaluate((v,t)=>v.currentTime=t,(s.start_ms+s.end_ms)/2000);
   await expect(page.locator('#observed-caption')).toHaveText('Focus: '+s.label);
   await expect(page.locator('#gherkin-steps button[aria-current=true]')).toHaveAttribute('data-sequence',String(s.step_sequence));
   await expect.poll(()=>page.locator('#video-layer').evaluate(el=>new DOMMatrix(getComputedStyle(el).transform).a)).toBeGreaterThan(1);
 }
 await page.locator('#smart-zoom').uncheck();
 await expect.poll(()=>page.locator('#video-layer').evaluate(el=>new DOMMatrix(getComputedStyle(el).transform).a)).toBe(1);
 await page.locator('#smart-zoom').check();
 await page.locator('#observed-cc').uncheck();await expect(page.locator('#observed-caption')).toHaveText('');
 assert.equal(await video.evaluate(v=>v.textTracks[0].mode),'disabled');
 await page.locator('#observed-cc').check();
 assert.equal(await video.evaluate(v=>v.textTracks[0].mode),'hidden');
 await video.evaluate(v=>v.currentTime=0);
 await expect(page.locator('#gherkin-steps button[aria-current=true]')).toHaveCount(0);
 await expect(page.locator('#observed-caption')).toHaveText('');
 await page.locator('#video-play').click();await expect.poll(()=>video.evaluate(v=>v.currentTime)).toBeGreaterThan(0.1);await page.locator('#video-play').click();
 const first=segments[0];await page.locator('#gherkin-steps button[data-sequence="'+first.step_sequence+'"]').click();
 await expect.poll(()=>video.evaluate((v,t)=>Math.abs(v.currentTime-t),first.start_ms/1000)).toBeLessThan(0.06);
 await video.evaluate((v,t)=>v.currentTime=t,(first.start_ms+first.end_ms)/2000);
 await expect(page.locator('#observed-caption')).toHaveText('Focus: '+first.label);
 await page.screenshot({path:path.join(path.dirname(file),'core-replay-desktop.png')});
 await expect.poll(()=>video.evaluate(v=>Array.from(v.textTracks).map(t=>t.activeCues?.length||0))).toEqual([1,1]);
 const other=data.cases.findIndex(c=>!c.videos.length);assert.ok(other>=0);
 await page.locator('#case-select').selectOption(String(other));
 await expect(page.locator('#observed-actions')).toBeHidden();
 await expect(page.locator('#no-evidence-title')).toHaveText('No replay captured');
 await expect(page.locator('#dom-evidence')).toBeHidden();
 await expect(page.locator('#open-recorded-case')).toBeVisible();
 assert.deepEqual(await video.evaluate(v=>Array.from(v.textTracks).map(t=>t.mode)),['disabled','disabled']);
 await page.locator('#open-recorded-case').click();
 await expect(page.locator('#case-select')).toHaveValue(String(idx));
 await expect.poll(()=>video.evaluate(v=>v.readyState>=1)).toBe(true);
 assert.deepEqual(await video.evaluate(v=>Array.from(v.textTracks).map(t=>({kind:t.kind,count:t.cues.length}))),[{kind:'captions',count:6},{kind:'chapters',count:6}]);
 assert.deepEqual(errors,[]);
 console.log('Verified core Report export, observed action seek, step seek, active step, unmapped gaps, zoom and focus captions.');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
