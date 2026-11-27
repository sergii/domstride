// Explicit, local Playwright evidence capture. The caller owns the page and test lifecycle.
const {mkdir,writeFile,stat}=require('node:fs/promises');
const {join}=require('node:path');
const {performance}=require('node:perf_hooks');
class PlaywrightRecorder {
 constructor({page,directory,profile,size}){
  if(!['execution','guided'].includes(profile))throw Error('Invalid recording profile');
  this.page=page;this.directory=directory;this.profile=profile;this.size=size;
  this.screenshots=[];this.errors=[];this.frameObservations=[];this.recordingWindow=null;
  this.presentationWaitMs=0;this.started=false;this.startAttempted=false;this.video=null;
 }
 async prepare(){
  await mkdir(this.directory,{recursive:true});
  if(this.profile==='guided')await mkdir(join(this.directory,'screenshots'),{recursive:true});
 }
 async start(){
  if(this.startAttempted)throw Error('Recording already requested');
  this.startAttempted=true;
  const options={path:join(this.directory,'video-01.webm'),size:this.size};
  if(this.profile==='guided'){
   this.recordingWindow={startWallMs:Date.now(),startMonotonicMs:performance.now()};
   options.onFrame=({data})=>this.frameObservations.push({sequence:this.frameObservations.length+1,bytes:data.length,receivedWallMs:Date.now(),receivedMonotonicMs:performance.now()});
  }
  try{await this.page.screencast.start(options);this.started=true;}
  catch(error){this.recordingWindow=null;this.errors.push('Video start: '+String(error));}
 }
 async hold(ms){
  if(this.profile!=='guided')return;
  this.presentationWaitMs+=ms;
  await this.page.waitForTimeout(ms);
 }
 async checkpoint(stepId,holdMs=0){
  if(this.profile!=='guided'||!this.started)return;
  const file='screenshots/step-'+String(this.screenshots.length+1).padStart(3,'0')+'.png';
  try{
   await this.page.screenshot({path:join(this.directory,file),animations:'disabled'});
   this.screenshots.push({stepId,file,url:this.page.url(),phase:'after'});
   await this.hold(holdMs);
  }catch(error){this.errors.push('Screenshot: '+String(error));}
 }
 async stop(){
  if(!this.started)return;
  this.started=false;
  try{
   await this.page.screencast.stop();
   if(this.recordingWindow){this.recordingWindow.endWallMs=Date.now();this.recordingWindow.endMonotonicMs=performance.now();}
   const info=await stat(join(this.directory,'video-01.webm'));
   if(!info.isFile()||!info.size)throw Error('Missing finalized video');
   this.video='video-01.webm';
  }catch(error){this.errors.push('Video: '+String(error));}
 }
 async writeCapture({focusCount=0}={}){
  if(this.started)throw Error('Stop recording before writing capture');
  await writeFile(join(this.directory,'capture.json'),JSON.stringify({
   screenshots:this.screenshots,video:this.video,errors:this.errors,profile:this.profile,
   presentation_wait_ms:this.presentationWaitMs,focus_count:focusCount
  },null,2));
 }
}
module.exports={PlaywrightRecorder};
