// Independent real-browser smoke: no Rails, Cucumber or Petstore server.
const {chromium}=require('@playwright/test');
const {PlaywrightRecorder}=require('../../lib/domstride/documentation/playwright-recorder.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs/promises'),os=require('node:os'),path=require('node:path');
async function main(){
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'library-recorder-'));
 let browser;
 try{
  browser=await chromium.launch();
  const page=await browser.newPage({viewport:{width:640,height:480}});
  await page.setContent('<button onclick="this.textContent=\'Borrowed\'">Borrow</button>');
  const recorder=new PlaywrightRecorder({page,directory:root,profile:'guided',size:{width:640,height:480}});
  await recorder.prepare();await recorder.start();
  await page.getByRole('button',{name:'Borrow',exact:true}).click();
  await recorder.checkpoint('borrow',400);await recorder.stop();await recorder.writeCapture();
  assert.deepEqual(recorder.errors,[]);
  assert.equal(recorder.screenshots.length,1);assert.ok(recorder.frameObservations.length>0);
  assert.equal((await fs.readFile(path.join(root,'video-01.webm'))).subarray(0,4).toString('hex'),'1a45dfa3');
  assert.equal((await fs.readFile(path.join(root,recorder.screenshots[0].file))).subarray(0,8).toString('hex'),'89504e470d0a1a0a');
 }finally{try{await browser?.close();}finally{await fs.rm(root,{recursive:true,force:true});}}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
