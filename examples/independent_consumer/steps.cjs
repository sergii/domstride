const {Before,After,AfterStep,Given,When,Then,setDefaultTimeout}=require('@cucumber/cucumber');
const {chromium,expect}=require('@playwright/test');
const {join}=require('node:path');
const {PlaywrightRecorder}=require(join(process.env.INSTALLED_DOCS_LIB,'playwright-recorder.cjs'));
setDefaultTimeout(30000);
Before(async function({testCaseStartedId}){
 this.browser=await chromium.launch();
 this.page=await this.browser.newPage({viewport:{width:640,height:480}});
 if(process.env.RUN_MODE!=='fast'){
  if(!/^[A-Za-z0-9-]+$/.test(testCaseStartedId))throw Error('Invalid attempt ID');
  this.recorder=new PlaywrightRecorder({page:this.page,directory:join(process.env.ARTIFACT_ROOT,'domstride-case-'+testCaseStartedId),profile:process.env.RUN_MODE==='execution'?'execution':'guided',size:{width:640,height:480}});
  await this.recorder.prepare();
 }
});
Given('an available book',async function(){
 await this.page.goto(process.env.LIBRARY_URL);
 await expect(this.page.getByRole('status')).toHaveText('Available');
 await this.recorder?.start();
});
When('I borrow the book',async function(){
 await this.page.getByRole('button',{name:'Borrow book'}).click();
 await expect(this.page.getByRole('button',{name:'Borrow book'})).toBeDisabled();
});
Then('the book is marked as borrowed',async function(){
 await expect(this.page.getByRole('status')).toHaveText('Borrowed');
});
AfterStep(async function({testStepId,result}){
 if(result?.status==='PASSED')await this.recorder?.checkpoint(testStepId,400);
});
After(async function(){
 try{await this.recorder?.stop();await this.recorder?.writeCapture();}
 finally{await this.browser?.close();}
});
