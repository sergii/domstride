// Test the packaged adapter with an unrelated synthetic domain, no test runner or browser.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const lib=process.argv[2]||path.resolve(__dirname,'../lib/domstride/documentation');
const {writeCucumberRun}=require(path.join(lib,'cucumber-run-adapter.cjs'));
const {validateDocumentationRun}=require(path.join(lib,'artifact-validation.cjs'));
const root=fs.mkdtempSync(path.join(os.tmpdir(),'library-adapter-'));
const scenario={id:'s',name:'Borrow',tags:[{name:'@scenario:LIB-01'}],steps:[{id:'st',keyword:'When ',text:'Borrow',location:{line:3}}]};
const messages=[
 {gherkinDocument:{uri:'library.feature',feature:{name:'Library',tags:[{name:'@feature:LIB'}],children:[{scenario}]}}},
 {pickle:{id:'p',name:'Borrow',uri:'library.feature',astNodeIds:['s'],steps:[{id:'ps',astNodeIds:['st'],text:'Borrow'}]}},
 {testCase:{id:'t',pickleId:'p',testSteps:[{id:'ts',pickleStepId:'ps'}]}},
 {testCaseStarted:{id:'a',testCaseId:'t',attempt:0}},
 {testStepFinished:{testCaseStartedId:'a',testStepId:'ts',testStepResult:{status:'PASSED',duration:{seconds:0,nanos:1000000}}}},
 {testCaseFinished:{testCaseStartedId:'a',willBeRetried:false}}
];
const metadata={producer:'library',framework:'cucumber-js',runner:'playwright',platform:'web',language:'javascript',browser:'chromium',viewport:{width:640,height:480},videoLabel:'Browser'};
try{
 for(const mode of ['fast','execution','documentation']){
  const dir=path.join(root,mode),caseDir=path.join(dir,'domstride-case-a');
  fs.mkdirSync(caseDir,{recursive:true});fs.writeFileSync(path.join(dir,'messages.ndjson'),messages.map(e=>JSON.stringify(e)).join('\n'));
  if(mode!=='fast'){
   const screenshots=mode==='documentation'?[{stepId:'ts',file:'screenshots/step-001.png',url:'http://localhost/library'}]:[];
   fs.mkdirSync(path.join(caseDir,'screenshots'));
   if(screenshots.length)fs.writeFileSync(path.join(caseDir,screenshots[0].file),'synthetic PNG placeholder');
   fs.writeFileSync(path.join(caseDir,'video-01.webm'),'synthetic WebM placeholder');
   fs.writeFileSync(path.join(caseDir,'capture.json'),JSON.stringify({screenshots,video:'video-01.webm',profile:mode==='documentation'?'guided':'execution',errors:[]}));
  }
  const input={run_id:mode,mode,exitCode:0};
  const result=writeCucumberRun(dir,input,metadata);
  validateDocumentationRun(result.specification,result.run,result.cases);
  assert.equal(result.cases[0].producer,'library');assert.equal(result.cases[0].videos.length,mode==='fast'?0:1);
  assert.equal(result.cases[0].screenshots.length,mode==='documentation'?1:0);
  assert.equal(result.cases[0].evidence_errors.length,0);
  assert.equal(fs.existsSync(path.join(dir,'documentation')),false);
  assert.throws(()=>writeCucumberRun(dir,input,metadata),/already materialized/);
 }
 // Existing packaged Playwright Test reporter remains independent of the Ruby runtime.
 if(process.argv[3]){
  const Reporter=require(path.join(process.argv[3],'playwright/reporter.cjs'));
  const output=path.join(root,'reporter');
  const reporter=new Reporter({directory:output});
  reporter.onTestEnd({parent:{project:()=>({name:'library'})},titlePath:()=>['Borrow']},{retry:0,status:'passed',duration:1,steps:[],attachments:[]});
  assert.equal(reporter.written,1);assert.equal(reporter.errors,0);
  const manifest=JSON.parse(fs.readFileSync(path.join(output,fs.readdirSync(output)[0],'case.json'),'utf8'));
  assert.equal(manifest.framework,'playwright-test');assert.equal(manifest.status,'passed');
 }
 console.log('Independent framework adapter smoke passed.');
}finally{fs.rmSync(root,{recursive:true,force:true});}
