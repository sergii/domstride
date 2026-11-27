const assert=require('node:assert/strict'),os=require('node:os'),path=require('node:path'),fs=require('node:fs/promises');
const {PlaywrightRecorder}=require('../lib/domstride/documentation/playwright-recorder.cjs');
async function main(){
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'recorder-'));
 try{
  for(const profile of ['execution','guided']){
   const calls=[];let video;
   const page={url:()=> 'http://localhost/library',waitForTimeout:async ms=>calls.push(['hold',ms]),
    screenshot:async o=>{calls.push(['screenshot']);await fs.writeFile(o.path,'fake');},
    screencast:{start:async o=>{calls.push(['start']);video=o.path;o.onFrame?.({data:Buffer.from('frame')});},
     stop:async()=>{calls.push(['stop']);await fs.writeFile(video,'fake');}}};
   const r=new PlaywrightRecorder({page,directory:path.join(root,profile),profile,size:{width:640,height:480}});
   await r.prepare();await r.start();await r.checkpoint('borrow',12);await r.stop();await r.writeCapture();
   const capture=JSON.parse(await fs.readFile(path.join(root,profile,'capture.json')));
   assert.equal(capture.video,'video-01.webm');assert.deepEqual(capture.errors,[]);
   assert.equal(capture.screenshots.length,profile==='guided'?1:0);
   assert.equal(r.frameObservations.length,profile==='guided'?1:0);
   assert.equal(capture.presentation_wait_ms,profile==='guided'?12:0);
   assert.deepEqual(calls.map(x=>x[0]),profile==='guided'?['start','screenshot','hold','stop']:['start','stop']);
   if(profile==='guided')assert.equal(capture.screenshots[0].stepId,'borrow');
  }
  const failed=new PlaywrightRecorder({page:{screencast:{start:async()=>{throw Error('unavailable');},stop:async()=>assert.fail('Not started')}},directory:path.join(root,'failed'),profile:'guided',size:{width:640,height:480}});
  await failed.prepare();await failed.start();await failed.stop();await failed.writeCapture();
  const capture=JSON.parse(await fs.readFile(path.join(root,'failed','capture.json')));
  assert.equal(capture.video,null);assert.equal(capture.errors.length,1);
 }finally{await fs.rm(root,{recursive:true,force:true});}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
