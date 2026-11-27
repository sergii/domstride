// Offline Cucumber Messages + explicit capture adapter for trusted local runs.
const fs=require('node:fs');
const path=require('node:path');
const {parseMessages,normalizeMessages}=require('./cucumber-messages.cjs');
const write=(file,data)=>fs.writeFileSync(file,JSON.stringify(data,null,2)+'\n');
function writeCucumberRun(root,run,{producer,framework,runner,platform,language,browser,viewport,videoLabel}){
 for(const [key,value] of Object.entries({producer,framework,runner,platform,language,browser,videoLabel})){
  if(typeof value!=='string'||!value.trim()||Buffer.byteLength(value)>128)throw Error('Invalid adapter metadata: '+key);
 }
 if(!viewport||!Number.isInteger(viewport.width)||viewport.width<=0||!Number.isInteger(viewport.height)||viewport.height<=0)throw Error('Invalid viewport');
 if(!['fast','execution','documentation'].includes(run.mode))throw Error('Invalid run mode');
 if(!/^[A-Za-z0-9-]{1,128}$/.test(run.run_id||''))throw Error('Invalid run ID');
 if(fs.existsSync(path.join(root,'run.json'))||fs.existsSync(path.join(root,'specification.json')))throw Error('Run already materialized');
 const {specification:spec,cases:normalized}=normalizeMessages(parseMessages(fs.readFileSync(path.join(root,'messages.ndjson'),'utf8')));
 const cases=[];
 for(const entry of normalized){
  const {attempt_id:attempt,steps}=entry;
  const folder='domstride-case-'+attempt,dir=path.join(root,folder);
  if(fs.existsSync(path.join(dir,'case.json')))throw Error('Case already materialized');
  fs.mkdirSync(dir,{recursive:true});
  const capturePath=path.join(dir,'capture.json');
  const capture=run.mode!=='fast'&&fs.existsSync(capturePath)?JSON.parse(fs.readFileSync(capturePath,'utf8')):{screenshots:[],video:null,errors:[]};
  const evidenceErrors=[...(capture.errors||[])];
  if(run.mode==='fast'&&fs.existsSync(capturePath))evidenceErrors.push('Unexpected capture in fast mode');
  const expectedProfile=run.mode==='documentation'?'guided':'execution';
  const usableCapture=capture.profile===expectedProfile; 
  if(capture.profile&&!usableCapture)evidenceErrors.push('Capture profile mismatch');
  const screenshots=(run.mode==='documentation'&&usableCapture?(capture.screenshots||[]):[]).filter(s=>/^screenshots\/step-\d{3}\.png$/.test(s.file)&&fs.existsSync(path.join(dir,s.file))).flatMap(s=>{
   const step=steps.find(t=>t.runtime_id===s.stepId);
   return step?[{file:s.file,step_sequence:step.sequence,source_step_id:step.source_step_id,phase:'after',url:s.url}]:[];
  });
  if((capture.screenshots||[]).length!==screenshots.length)evidenceErrors.push('One or more screenshots omitted: invalid mode, filename, missing file or step mapping');
  const video=usableCapture&&capture.video==='video-01.webm'&&fs.existsSync(path.join(dir,'video-01.webm'));
  if(capture.video&&!video)evidenceErrors.push('Video omitted: invalid profile, filename or missing file');
  const record={format:'domstride.case',schema_version:1,...entry,producer,framework,runner,platform,language,
   screenshots,videos:video?[{file:'video-01.webm',label:videoLabel,role:capture.profile,attempt_id:attempt,run_id:run.run_id}]:[],presentation_wait_ms:capture.presentation_wait_ms??0,evidence_errors:evidenceErrors,timing_quality:'unmapped'};
  cases.push({...record,folder});
 }
 const manifest={...run,format:'domstride.run',schema_version:1,platform,browser,viewport,status:run.exitCode===0?'passed':run.exitCode===null?'unknown':'failed',cases:cases.map(c=>({folder:c.folder,scenario_id:c.scenario_id,status:c.status,attempt_id:c.attempt_id}))};
 // Finalize the manifests only after collecting all attempt metadata.
 write(path.join(root,'specification.json'),spec);
 for(const {folder,...record} of cases)write(path.join(root,folder,'case.json'),record);
 write(path.join(root,'run.json'),manifest);
 return {specification:spec,cases,run:manifest};
}
module.exports={writeCucumberRun};
