// Real Cucumber + Chromium consumer of the installed gem, outside the source checkout.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const {spawn,execFileSync}=require('node:child_process');
const {pathToFileURL}=require('node:url');
const {chromium,expect}=require('@playwright/test');
const lib=process.env.INSTALLED_DOCS_LIB,cli=process.env.INSTALLED_DOMSTRIDE_CLI;
assert.ok(lib&&cli&&process.env.SOURCE_COMMIT);
const {writeCucumberRun}=require(path.join(lib,'cucumber-run-adapter.cjs'));
const {validateDocumentationRun}=require(path.join(lib,'artifact-validation.cjs'));
const app=fs.readFileSync('library.html');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const server=http.createServer((req,res)=>{if(req.url!=='/'){res.writeHead(404);res.end();return;}res.writeHead(200,{'content-type':'text/html; charset=utf-8'});res.end(app);});
const root=path.resolve('artifacts');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const write=(p,v)=>fs.writeFileSync(p,JSON.stringify(v,null,2));
const viewer=process.env.INDEPENDENT_VIEWER_CLI||cli;
const exec=(args)=>execFileSync(viewer,args,{stdio:'inherit'});
async function cucumber(directory,mode,url){
 await new Promise((resolve,reject)=>{
  const child=spawn(path.resolve('node_modules/.bin/cucumber-js'),['--require','steps.cjs','--format','progress','--format','message:'+path.join(directory,'messages.ndjson'),'library.feature'],{stdio:'inherit',env:{...process.env,ARTIFACT_ROOT:directory,RUN_MODE:mode,LIBRARY_URL:url}});
  child.on('error',reject);child.on('exit',(code,signal)=>code===0?resolve():reject(Error('Cucumber failed: '+code+' '+signal)));
 });
}
async function main(){
 fs.mkdirSync(root);
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
 const url='http://127.0.0.1:'+server.address().port+'/';
 const results={};
 try{
  for(const mode of ['fast','execution','documentation']){
   const directory=path.join(root,mode);fs.mkdirSync(directory);
   const start=new Date().toISOString();
   await cucumber(directory,mode,url);
   const result=writeCucumberRun(directory,{run_id:mode,mode,exitCode:0,start,end:new Date().toISOString(),source_sha256:sha(fs.readFileSync('library.feature')),applicationCommit:process.env.SOURCE_COMMIT,commit:process.env.SOURCE_COMMIT},{producer:'independent-library',framework:'cucumber-js',runner:'playwright',platform:'web',language:'javascript',browser:'chromium',viewport:{width:640,height:480},videoLabel:'Chromium'});
   validateDocumentationRun(result.specification,result.run,result.cases);
   assert.equal(result.cases.length,1);
   const c=result.cases[0];assert.equal(c.status,'passed');assert.equal(c.steps.length,3);assert.deepEqual(c.evidence_errors,[]);
   assert.equal(c.videos.length,mode==='fast'?0:1);
   assert.equal(c.screenshots.length,mode==='documentation'?3:0);
   assert.equal(c.presentation_wait_ms,mode==='documentation'?1200:0);
   if(mode==='fast')assert.ok(!fs.existsSync(path.join(directory,c.folder,'capture.json')));
   else assert.equal(fs.readFileSync(path.join(directory,c.folder,c.videos[0].file)).subarray(0,4).toString('hex'),'1a45dfa3');
   for(const s of c.screenshots){assert.equal(s.url,url);assert.equal(fs.readFileSync(path.join(directory,c.folder,s.file)).subarray(0,8).toString('hex'),'89504e470d0a1a0a');}
   results[mode]=c;
  }
 }finally{await new Promise(resolve=>server.close(resolve));}
 const g=results.documentation,e=results.execution;
 assert.notEqual(g.attempt_id,e.attempt_id);
 const guided=path.join(root,'documentation');
 write(path.join(guided,'video-pair.json'),{format:'domstride.reference-video-pair',schema_version:1,scenario_id:g.scenario_id,run_id:'execution',attempt_id:e.attempt_id,guided_run_id:'documentation',guided_attempt_id:g.attempt_id});
 exec(['docs','export','--synthetic-reference',guided]);
 const publication=path.join(guided,'static-export'),manifest=read(path.join(publication,'manifest.json'));
 assert.equal(manifest.pages.length,1);assert.equal(manifest.media.length,5);
 for(const m of manifest.media){const bytes=fs.readFileSync(path.join(publication,m.file));assert.equal(sha(bytes),m.sha256);assert.equal(bytes.length,m.size_bytes);}
 const md=fs.readFileSync(path.join(publication,manifest.pages[0].markdown),'utf8'),mdx=fs.readFileSync(path.join(publication,manifest.pages[0].mdx),'utf8');
 assert.match(md,/I borrow the book/);assert.match(md,/Actual outcome: passed/);assert.equal((mdx.match(/<video /g)||[]).length,2);
 assert.ok(!fs.existsSync(path.join(publication,'messages.ndjson')));
 const replay=path.join(root,'replay.html');
 exec(['report',guided,replay]);
 if(viewer!==cli){
  const legacy=path.join(root,'legacy-replay.html');
  execFileSync(cli,['report',guided,legacy],{stdio:'inherit'});
  const payload=p=>fs.readFileSync(p,'utf8').split('<script type="application/json" id="recording-data">')[1].split('</script>')[0];
  assert.deepEqual(JSON.parse(payload(replay)),JSON.parse(payload(legacy)));
 }
 const browser=await chromium.launch();
 try{
  const page=await browser.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.route('http://**/*',r=>r.abort());await page.route('https://**/*',r=>r.abort());
  await page.goto(pathToFileURL(replay).href);
  const data=JSON.parse(await page.locator('#recording-data').textContent());
  assert.equal(data.cases.length,1);assert.equal(data.cases[0].status,'passed');
  await expect(page.locator('#video-evidence')).toBeVisible();
  const video=page.locator('#browser-video');
  await expect.poll(()=>video.evaluate(v=>v.readyState>=1&&Number.isFinite(v.duration)&&v.duration>0)).toBe(true);
  await page.locator('#video-play').click();
  await expect.poll(()=>video.evaluate(v=>v.currentTime)).toBeGreaterThan(0);
  assert.deepEqual(errors,[]);
  await page.screenshot({path:path.join(root,'replay.png')});
 }finally{await browser.close();}
 console.log('Verified installed-gem producer and artifact consumer: actual Cucumber, Chromium, three modes, protocol, static export and offline video replay.');
}
main().catch(e=>{server.close();console.error(e);process.exitCode=1;});
