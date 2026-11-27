// Run against a built static site, not the Rails application.
const {chromium,expect}=require('@playwright/test');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
(async()=>{
 const base=process.env.HELP_CENTER_URL||'http://127.0.0.1:4321';
 const publication=JSON.parse(fs.readFileSync(path.join(__dirname,'generated-publication.json'),'utf8'));
 const browser=await chromium.launch();
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1000}});
  const response=await page.goto(base+'/generated/lst-001-01/');assert.equal(response.status(),200);
  await expect(page.getByRole('heading',{name:'Publish a valid listing',exact:true})).toBeVisible();
  await expect(page.locator('main ol li').first()).toBeVisible();
  await expect(page.locator('main img')).toHaveCount(6);
  for(const img of await page.locator('main img').all()){await img.scrollIntoViewIfNeeded();await expect.poll(()=>img.evaluate(el=>el.complete&&el.naturalWidth>0)).toBe(true);}
  await expect(page.locator('main video')).toHaveCount(2);
  for(const video of await page.locator('main video').all()){
   await video.scrollIntoViewIfNeeded();
   await expect.poll(()=>video.evaluate(el=>el.readyState>=1&&Number.isFinite(el.duration)&&el.duration>0)).toBe(true);
   await video.evaluate(async el=>{el.muted=true;await el.play();});
   await expect.poll(()=>video.evaluate(el=>el.currentTime)).toBeGreaterThan(0);
   await video.evaluate(el=>el.pause());
  }
  await page.evaluate(()=>window.scrollTo(0,0));
  await page.screenshot({path:path.join(__dirname,'help-center-desktop.png'),fullPage:false});
  await page.setViewportSize({width:390,height:844});await page.reload();
  await expect(page.getByRole('heading',{name:'Publish a valid listing',exact:true})).toBeVisible();
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'Mobile page overflow');
  await page.screenshot({path:path.join(__dirname,'help-center-mobile.png')});
  for(const file of publication.pages){const result=await page.goto(base+'/generated/'+file.replace(/\.mdx$/,'')+'/');assert.equal(result.status(),200);}
  console.log('Verified Starlight build, scenario routes, steps, six screenshots, two playable videos, mobile viewport.');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
