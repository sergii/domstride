import { Before, BeforeStep, After, AfterStep, Given, When, Then, World, setWorldConstructor, setDefaultTimeout } from '@cucumber/cucumber';
import type { DataTable } from '@cucumber/cucumber';
import { chromium, expect } from '@playwright/test';
import type { Browser, BrowserContext, Page, Locator } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

type Screenshot = { stepId: string; file: string; url: string; phase: 'after' };
type ElementInfo = {tag:string; id?:string; name?:string; test_id?:string; type?:string; label?:string};
type FocusObservation = { element?:ElementInfo; transition?: 'navigation'; stepId: string; action: number; observedWallMs: number; observedMonotonicMs: number; bounds: {x:number;y:number;width:number;height:number}; viewport: {width:number;height:number} };
type FrameObservation = { sequence:number; bytes:number; receivedWallMs:number; receivedMonotonicMs:number };
class ListingWorld extends World {
  browser?: Browser;
  context?: BrowserContext;
  page!: Page;
  directory?: string;
  screenshots: Screenshot[] = [];
  evidenceErrors: string[] = [];
  title = '';
  seller = '';
  profile: 'execution' | 'guided' | null = null;
  presentationWaitMs = 0;
  focusCount = 0;
  currentStepId = '';
  focusObservations: FocusObservation[] = [];
  submitSourceUrl?: string;
  frameObservations: FrameObservation[] = [];
  recordingWindow: {startWallMs:number;startMonotonicMs:number;endWallMs?:number;endMonotonicMs?:number} | null = null;

  stepMarkers: {step_id:string; boundary:'start'|'end'; code:number}[]=[];
  async markStep(stepId:string,boundary:'start'|'end'){
    if(this.profile!=='guided'||!this.recordingWindow)return;
    const code=this.stepMarkers.length+1;
    if(code>255)throw Error('Reference step marker limit exceeded');
    // Brief visible calibration landmark, separate from application behavior.
    try{
      await this.page.evaluate(code=>{
        const marker=document.createElement('div');
        marker.id='domstride-step-landmark';
        marker.style.cssText='position:fixed;right:8px;bottom:8px;width:32px;height:32px;display:grid;grid-template-columns:repeat(4,8px);grid-template-rows:repeat(4,8px);z-index:2147483647;pointer-events:none;background:white;margin:0;padding:0;border:0';
        const magic=['#ff00ff','#00ffff','#ff00ff','#00ffff'];
        const bits=Array.from({length:8},(_,i)=>(code&(1<<(7-i)))?'#ffffff':'#000000');
        for(const color of [...magic,...bits,...magic.slice().reverse()]){
          const cell=document.createElement('span');cell.style.cssText='display:block;width:8px;height:8px;background:'+color+';margin:0;padding:0;border:0';marker.append(cell);
        }
        document.body.append(marker);
      },code);
      this.stepMarkers.push({step_id:stepId,boundary,code});
      await this.hold(160);
    }catch(error){this.evidenceErrors.push('Step landmark: '+String(error));}
    finally{await this.page.evaluate(()=>document.getElementById('domstride-step-landmark')?.remove());}
  }
  async withFocus(target: Locator, action: () => Promise<void>, beforeMs=0, afterMs=0) {
    if (this.profile !== 'guided') { await action(); return; }
    // Reference presentation only: no geometry reads or DOM writes in unpaced execution.
    let highlighted = false;
    try {
      await target.scrollIntoViewIfNeeded();
      highlighted = await target.evaluate(el => {
        const doc=el.ownerDocument;
        const style=doc.createElement('style');
        style.id='domstride-reference-focus-style';
        style.textContent='[data-domstride-reference-focus] { outline: 3px solid #2563eb !important; outline-offset: 4px !important; }';
        doc.head.append(style);
        el.setAttribute('data-domstride-reference-focus','');
        const computed=getComputedStyle(el);
        return computed.outlineColor==='rgb(37, 99, 235)' && computed.outlineWidth==='3px';
      });
      if (!highlighted) throw new Error('Focus outline was not applied');
      this.focusCount++;
      const geometry=await target.evaluate(el=>{
        const rect=el.getBoundingClientRect();
        const type=el.getAttribute('type')||'';
        const element: ElementInfo|undefined=['password','hidden','file'].includes(type.toLowerCase())?undefined:{tag:el.localName};
        if(element)for(const [key,attr] of [['id','id'],['name','name'],['test_id','data-testid'],['type','type'],['label','aria-label']] as const){
          const value=el.getAttribute(attr);
          if(value&&value.length<=128)element[key]=value;
        }
        return {bounds:{x:rect.x,y:rect.y,width:rect.width,height:rect.height},viewport:{width:window.innerWidth,height:window.innerHeight},element};
      });
      this.focusObservations.push({stepId:this.currentStepId,action:this.focusCount,observedWallMs:Date.now(),observedMonotonicMs:performance.now(),...geometry});
      await this.hold(beforeMs);
    } catch(error) { this.evidenceErrors.push('Target focus: '+String(error)); }
    try {
      await action();
      if (highlighted && this.focusCount===1 && this.directory) {
        // Internal diagnostic evidence only, not a published checkpoint.
        try { await this.page.screenshot({path:join(this.directory,'focus-proof.png'),animations:'disabled'}); }
        catch(error) { this.evidenceErrors.push('Focus proof: '+String(error)); }
      }
      await this.hold(afterMs);
    } finally {
      try {
        await this.page.evaluate(() => {
          document.querySelectorAll('[data-domstride-reference-focus]').forEach(el=>el.removeAttribute('data-domstride-reference-focus'));
          document.getElementById('domstride-reference-focus-style')?.remove();
        });
      } catch(error) { this.evidenceErrors.push('Focus cleanup: '+String(error)); }
    }
  }
  async hold(ms: number) {
    if (this.profile !== 'guided') return;
    this.presentationWaitMs += ms;
    await this.page.waitForTimeout(ms);
  }
}
setWorldConstructor(ListingWorld);
setDefaultTimeout(30_000);
const base = process.env.PETSTORE_BASE_URL || '';
const url = (path: string) => new URL(path, base).href;

Before(async function(this: ListingWorld, {pickle, testCaseStartedId}) {
  const record = ['documentation','execution'].includes(process.env.RUN_MODE||'') && pickle.tags.some(t=>t.name==='@replay');
  const root = process.env.DOMSTRIDE_ARTIFACTS;
  if (!root || !/^[a-zA-Z0-9-]+$/.test(testCaseStartedId)) throw new Error('Invalid run or attempt');
  if (!['localhost','127.0.0.1','[::1]'].includes(new URL(base).hostname)) throw new Error('Only isolated local Petstore is supported');
  if (record) {
    this.profile = process.env.RUN_MODE === 'execution' ? 'execution' : 'guided';
    this.directory = join(root, 'domstride-case-'+testCaseStartedId);
    await mkdir(this.directory, {recursive:true});
    if (this.profile === 'guided') await mkdir(join(this.directory,'screenshots'), {recursive:true});
  }
  this.browser = await chromium.launch();
  this.context = await this.browser.newContext({viewport:{width:1280,height:800}});
  this.page = await this.context.newPage();
});

BeforeStep(async function(this: ListingWorld,{testStepId}) {
  if(this.profile==='guided'){this.currentStepId=testStepId;await this.markStep(testStepId,'start');}
});

AfterStep(async function(this: ListingWorld,{pickleStep,testStepId,result}) {
  if (!this.directory || this.profile !== 'guided' || result?.status !== 'PASSED') return;
  const selected = [
    'the seller has no listing titled "Travel carrier demo"',
    'the seller creates a listing',
    'enters the following listing details:',
    'a publication confirmation should be displayed',
    'the listing should appear in the seller\'s listings',
    'the listing should be visible to a guest buyer'
  ];
  if (!selected.includes(pickleStep.text)) {if(this.stepMarkers.some(m=>m.step_id===testStepId&&m.boundary==='start'))await this.markStep(testStepId,'end');return;}
  const file = 'screenshots/step-'+String(this.screenshots.length+1).padStart(3,'0')+'.png';
  try {
    await this.page.screenshot({path:join(this.directory,file),animations:'disabled'});
    this.screenshots.push({stepId:testStepId,file,url:this.page.url(),phase:'after'});
    await this.hold(pickleStep.text.includes('guest buyer') ? 1800 : pickleStep.text.includes('confirmation') ? 1500 : 1100);
  } catch(error) { this.evidenceErrors.push('Screenshot: '+String(error)); }
  if(this.stepMarkers.some(m=>m.step_id===testStepId&&m.boundary==='start'))await this.markStep(testStepId,'end');
});

After(async function(this: ListingWorld) {
  let file: string | null = null;
  try {
    if (this.directory) {
      await this.page.screencast.stop();
      if(this.recordingWindow){this.recordingWindow.endWallMs=Date.now();this.recordingWindow.endMonotonicMs=performance.now();}
      file = 'video-01.webm';
    }
  } catch(error) { this.evidenceErrors.push('Video: '+String(error)); }
  finally { try { await this.context?.close(); } finally { await this.browser?.close(); } }
  if (this.directory) {
    if(this.profile==='guided') await writeFile(join(this.directory,'focus-observations.json'),JSON.stringify({
      format:'domstride.reference-focus-observations',schema_version:1,timing_quality:'unmapped',outline_color:'#2563eb',
      recording_window:this.recordingWindow,targets:this.focusObservations,frames:this.frameObservations,step_markers:this.stepMarkers
    },null,2));
    await writeFile(join(this.directory,'capture.json'),JSON.stringify({
      screenshots:this.screenshots,video:file,errors:this.evidenceErrors,profile:this.profile,presentation_wait_ms:this.presentationWaitMs,focus_count:this.focusCount
    },null,2));
  }
});

Given('a registered seller named {string} exists',function(this:ListingWorld,name:string){
  // The isolated Rails database is seeded by the reference setup.
  this.seller=name;
});
Given('the seller is signed in',async function(this:ListingWorld){
  await this.page.goto(url('/session/new'));
  await this.page.getByLabel('Email address').fill('seller@example.test');
  await this.page.getByLabel('Password',{exact:true}).fill('synthetic-demo-password');
  await this.page.getByRole('button',{name:'Sign in',exact:true}).click();
  await expect(this.page.getByRole('link',{name:'My listings'})).toBeVisible();
  await expect(this.page.locator('.user-name')).toHaveText(this.seller);
  // Start recording after authentication; no login fields appear in the recording.
  if(this.directory) {
    try {
      if(this.profile==='guided'){
        this.recordingWindow={startWallMs:Date.now(),startMonotonicMs:performance.now()};
        await this.page.screencast.start({path:join(this.directory,'video-01.webm'),size:{width:1280,height:800},
          onFrame:({data})=>{
            this.frameObservations.push({sequence:this.frameObservations.length+1,bytes:data.length,receivedWallMs:Date.now(),receivedMonotonicMs:performance.now()});
          }});
      }else await this.page.screencast.start({path:join(this.directory,'video-01.webm'),size:{width:1280,height:800}});
    }
    catch(error) { this.evidenceErrors.push('Video start: '+String(error)); }
  }
});
Given('the seller has no listing titled {string}',async function(this:ListingWorld,title:string){
  await this.page.getByRole('link',{name:'My listings'}).click();
  await expect(this.page.getByRole('heading',{name:'My listings'})).toBeVisible();
  await expect(this.page.getByRole('heading',{name:title,exact:true})).toHaveCount(0);
});
When('the seller creates a listing',async function(this:ListingWorld){
  await this.page.goto(url('/listings/new'));
  await expect(this.page.getByRole('button',{name:'Publish listing'})).toBeVisible();
});
When('enters the following listing details:',async function(this:ListingWorld,table:DataTable){
  const details=table.rowsHash();this.title=details.title;
  // Apply a visible focus outline during each guided field action.
  const title=this.page.getByLabel('Title',{exact:true});
  const description=this.page.getByLabel('Description',{exact:true});
  const category=this.page.getByLabel('Category',{exact:true});
  const condition=this.page.getByLabel('Condition',{exact:true});
  const price=this.page.getByLabel('Price (USD)',{exact:true});
  await this.withFocus(title,()=>title.fill(details.title),200,650);
  await this.withFocus(description,()=>description.fill(details.description),200,650);
  await this.withFocus(category,()=>category.selectOption({label:details.category}).then(()=>{}),200,650);
  await this.withFocus(condition,()=>condition.selectOption({label:details.condition}).then(()=>{}),200,650);
  await this.withFocus(price,()=>price.fill(details.price),200,650);
});
When('publishes the listing',async function(this:ListingWorld){const button=this.page.getByRole('button',{name:'Publish listing'});if(this.profile==='guided')this.submitSourceUrl=this.page.url();await this.withFocus(button,()=>button.click(),700);});
When('enters a price of {string}',async function(this:ListingWorld,price:string){
  const input=this.page.getByLabel('Price (USD)',{exact:true});
  await input.fill('');
  // A native number field rejects alphabetic input; exercise the actual keyboard behavior.
  await input.pressSequentially(price);
});
When('attempts to publish the listing',async function(this:ListingWorld){await this.page.getByRole('button',{name:'Publish listing'}).click();});
Then('a publication confirmation should be displayed',async function(this:ListingWorld){
  await expect(this.page.locator('.flash[role=status]')).toHaveText('Listing published.');
  if(this.profile==='guided'&&this.submitSourceUrl&&this.page.url()!==this.submitSourceUrl){const focus=this.focusObservations.at(-1);if(focus)focus.transition='navigation';}
  await expect(this.page.getByRole('heading',{name:this.title,exact:true})).toBeVisible();
});
Then('the listing price should be {string}',async function(this:ListingWorld,price:string){await expect(this.page.locator('.detail .price')).toHaveText(price);});
Then("the listing should appear in the seller's listings",async function(this:ListingWorld){
  await this.page.getByRole('link',{name:'My listings'}).click();
  await expect(this.page.getByRole('heading',{name:this.title,exact:true})).toBeVisible();
});
Then('the listing should be visible to a guest buyer',async function(this:ListingWorld){
  await this.page.getByRole('button',{name:'Sign out'}).click();
  await expect(this.page.getByRole('link',{name:'Sign in'})).toBeVisible();
  await this.page.goto(url('/'));
  await expect(this.page.getByRole('heading',{name:this.title,exact:true})).toBeVisible();
});
Then('a price validation error should be displayed',async function(this:ListingWorld){
  const price=this.page.getByLabel('Price (USD)',{exact:true});
  // Native browser validation is observable through the validity state and message.
  await expect(price).toBeVisible();
  expect(await price.evaluate(el=>({valid:(el as HTMLInputElement).validity.valid,message:(el as HTMLInputElement).validationMessage}))).toEqual({valid:false,message:expect.any(String)});
  expect(await price.evaluate(el=>(el as HTMLInputElement).validationMessage)).not.toBe('');
  await expect(this.page).toHaveURL(/\/listings\/new$/);
});
Then('the listing {string} should not be published',async function(this:ListingWorld,title:string){
  await this.page.getByRole('link',{name:'My listings'}).click();
  await expect(this.page.getByRole('heading',{name:'My listings'})).toBeVisible();
  await expect(this.page.getByRole('heading',{name:title,exact:true})).toHaveCount(0);
});
