const {chromium,expect}=require('@playwright/test');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
(async()=>{
 const base=process.env.HELP_CENTER_URL||'http://127.0.0.1:4322';
 const publication=JSON.parse(fs.readFileSync(path.join(__dirname,'generated-publication.json'),'utf8'));
 const browser=await chromium.launch();
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1000}});
  assert.equal((await page.goto(base+'/docs/generated/lst-001-01/')).status(),200);
  await expect(page.getByRole('heading',{name:'Publish a valid listing',exact:true})).toBeVisible();
  const guide=page.locator('[data-domstride-guide]');
  console.log('Guide headings:',await guide.locator('h2,h3,h4').allTextContents());
  console.log('Guide accessibility:',await guide.ariaSnapshot());
  for(const name of ['Overview','Actors','Prerequisites','Initial context','Walkthrough','Expected results','Video walkthrough'])await expect(guide.getByRole('heading',{name:new RegExp('^'+name+'(?:\\s*Copy Anchor Link)?).toBeVisible();
  await expect(guide.locator('h4')).toHaveCount(3);
  await expect(guide.locator('img')).toHaveCount(6);
  for(const img of await guide.locator('img').all()){await img.scrollIntoViewIfNeeded();await expect.poll(()=>img.evaluate(el=>el.complete&&el.naturalWidth>0)).toBe(true);}
  await expect(guide.locator('video')).toHaveCount(2);
  for(const video of await guide.locator('video').all()){await video.scrollIntoViewIfNeeded();await expect.poll(()=>video.evaluate(el=>el.readyState>=1&&Number.isFinite(el.duration)&&el.duration>0)).toBe(true);await video.evaluate(async el=>{el.muted=true;await el.play();});await expect.poll(()=>video.evaluate(el=>el.currentTime)).toBeGreaterThan(0);await video.evaluate(el=>el.pause());}
  const details=guide.locator('details').filter({hasText:'Technical details and verification'});await expect(details).toHaveCount(1);assert.equal(await details.evaluate(el=>el.open),false);await details.locator('summary').click();await expect(details.getByText('Original executed steps (including setup):')).toBeVisible();await details.locator('summary').click();
  await expect(guide.getByRole('link',{name:'Reject an invalid listing price',exact:true})).toHaveAttribute('href','/docs/generated/lst-001-02/');
  await page.evaluate(()=>window.scrollTo(0,0));await page.screenshot({path:path.join(__dirname,'help-center-desktop.png')});
  await page.setViewportSize({width:390,height:844});await page.reload();await expect(page.getByRole('heading',{name:'Publish a valid listing',exact:true})).toBeVisible();assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'Mobile overflow');await page.screenshot({path:path.join(__dirname,'help-center-mobile.png')});
  for(const file of publication.pages)assert.equal((await page.goto(base+'/docs/generated/'+file.replace(/\.mdx$/,'')+'/')).status(),200);
  console.log('Verified Fumadocs static routes, steps, screenshots, two playable videos and responsive layout.');
 }catch(error){const page=browser.contexts()[0]?.pages()[0];if(page){await page.screenshot({path:path.join(__dirname,'help-center-failure.png'),fullPage:true}).catch(()=>{});fs.writeFileSync(path.join(__dirname,'failure.html'),await page.content());}throw error;}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
,'i')})).toBeVisible();
  await expect(guide.locator('h4')).toHaveCount(3);
  await expect(guide.locator('img')).toHaveCount(6);
  for(const img of await guide.locator('img').all()){await img.scrollIntoViewIfNeeded();await expect.poll(()=>img.evaluate(el=>el.complete&&el.naturalWidth>0)).toBe(true);}
  await expect(guide.locator('video')).toHaveCount(2);
  for(const video of await guide.locator('video').all()){await video.scrollIntoViewIfNeeded();await expect.poll(()=>video.evaluate(el=>el.readyState>=1&&Number.isFinite(el.duration)&&el.duration>0)).toBe(true);await video.evaluate(async el=>{el.muted=true;await el.play();});await expect.poll(()=>video.evaluate(el=>el.currentTime)).toBeGreaterThan(0);await video.evaluate(el=>el.pause());}
  const details=guide.locator('details').filter({hasText:'Technical details and verification'});await expect(details).toHaveCount(1);assert.equal(await details.evaluate(el=>el.open),false);await details.locator('summary').click();await expect(details.getByText('Original executed steps (including setup):')).toBeVisible();await details.locator('summary').click();
  await expect(guide.getByRole('link',{name:'Reject an invalid listing price',exact:true})).toHaveAttribute('href','/docs/generated/lst-001-02/');
  await page.evaluate(()=>window.scrollTo(0,0));await page.screenshot({path:path.join(__dirname,'help-center-desktop.png')});
  await page.setViewportSize({width:390,height:844});await page.reload();await expect(page.getByRole('heading',{name:'Publish a valid listing',exact:true})).toBeVisible();assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'Mobile overflow');await page.screenshot({path:path.join(__dirname,'help-center-mobile.png')});
  for(const file of publication.pages)assert.equal((await page.goto(base+'/docs/generated/'+file.replace(/\.mdx$/,'')+'/')).status(),200);
  console.log('Verified Fumadocs static routes, steps, screenshots, two playable videos and responsive layout.');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
