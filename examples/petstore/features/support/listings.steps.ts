import { Before, After, AfterStep, Given, When, Then, World, setWorldConstructor, setDefaultTimeout } from '@cucumber/cucumber';
import type { DataTable } from '@cucumber/cucumber';
import { chromium, expect } from '@playwright/test';
import type { Browser, BrowserContext, Page } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

type Screenshot = { stepId: string; file: string; url: string; phase: 'after' };
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
  if (!selected.includes(pickleStep.text)) return;
  const file = 'screenshots/step-'+String(this.screenshots.length+1).padStart(3,'0')+'.png';
  try {
    await this.page.screenshot({path:join(this.directory,file),animations:'disabled'});
    this.screenshots.push({stepId:testStepId,file,url:this.page.url(),phase:'after'});
    await this.hold(pickleStep.text.includes('guest buyer') ? 1800 : pickleStep.text.includes('confirmation') ? 1500 : 1100);
  } catch(error) { this.evidenceErrors.push('Screenshot: '+String(error)); }
});

After(async function(this: ListingWorld) {
  let file: string | null = null;
  try {
    if (this.directory) {
      await this.page.screencast.stop();
      file = 'video-01.webm';
    }
  } catch(error) { this.evidenceErrors.push('Video: '+String(error)); }
  finally { try { await this.context?.close(); } finally { await this.browser?.close(); } }
  if (this.directory) {
    await writeFile(join(this.directory,'capture.json'),JSON.stringify({
      screenshots:this.screenshots,video:file,errors:this.evidenceErrors,profile:this.profile,presentation_wait_ms:this.presentationWaitMs
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
    try { await this.page.screencast.start({path:join(this.directory,'video-01.webm'),size:{width:1280,height:800}}); }
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
  // Presentation pacing applies only to the recorded reference scenario.
  const pace=async()=>{await this.hold(650);};
  await this.page.getByLabel('Title',{exact:true}).fill(details.title); await pace();
  await this.page.getByLabel('Description',{exact:true}).fill(details.description); await pace();
  await this.page.getByLabel('Category',{exact:true}).selectOption({label:details.category}); await pace();
  await this.page.getByLabel('Condition',{exact:true}).selectOption({label:details.condition}); await pace();
  await this.page.getByLabel('Price (USD)',{exact:true}).fill(details.price); await pace();
});
When('publishes the listing',async function(this:ListingWorld){await this.hold(700);await this.page.getByRole('button',{name:'Publish listing'}).click();});
When('enters a price of {string}',async function(this:ListingWorld,price:string){
  const input=this.page.getByLabel('Price (USD)',{exact:true});
  await input.fill('');
  // A native number field rejects alphabetic input; exercise the actual keyboard behavior.
  await input.pressSequentially(price);
});
When('attempts to publish the listing',async function(this:ListingWorld){await this.page.getByRole('button',{name:'Publish listing'}).click();});
Then('a publication confirmation should be displayed',async function(this:ListingWorld){
  await expect(this.page.locator('.flash[role=status]')).toHaveText('Listing published.');
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
