// Reference artifact/media adapter for trusted synthetic runs.
const fs=require('node:fs');
const {render}=require('./render-docs.cjs');
const path=require('node:path');
const {parseMessages,normalizeMessages}=require('../../lib/domstride/documentation/cucumber-messages.cjs');
const write=(file,data)=>fs.writeFileSync(file,JSON.stringify(data,null,2)+'\n');
function generate(root,run){
 const {specification:spec,cases:normalized}=normalizeMessages(parseMessages(fs.readFileSync(path.join(root,'messages.ndjson'),'utf8')));
 const docs=spec.documents;
 write(path.join(root,'specification.json'),spec);
 const cases=[];
 for(const entry of normalized){
  const {attempt_id:attempt,steps}=entry;
  const folder='domstride-case-'+attempt,dir=path.join(root,folder);
  fs.mkdirSync(dir,{recursive:true});
  const capturePath=path.join(dir,'capture.json');
  const capture=fs.existsSync(capturePath)?JSON.parse(fs.readFileSync(capturePath,'utf8')):{screenshots:[],video:null,errors:[]};
  const screenshots=(capture.screenshots||[]).filter(s=>/^screenshots\/step-\d{3}\.png$/.test(s.file)&&fs.existsSync(path.join(dir,s.file))).flatMap(s=>{
   const step=steps.find(t=>t.runtime_id===s.stepId);
   return step?[{file:s.file,step_sequence:step.sequence,source_step_id:step.source_step_id,phase:'after',url:s.url}]:[];
  });
  const video=capture.video==='video-01.webm'&&fs.existsSync(path.join(dir,'video-01.webm'));
  const record={format:'domstride.case',schema_version:1,...entry,producer:'living-documentation-reference',framework:'cucumber-js',runner:'playwright',platform:'web',language:'typescript',
   screenshots,videos:video?[{file:'video-01.webm',label:'Chromium',role:capture.profile,attempt_id:attempt,run_id:run.run_id}]:[],presentation_wait_ms:capture.presentation_wait_ms??0,evidence_errors:capture.errors||[],timing_quality:'unmapped'};
  write(path.join(dir,'case.json'),record);
  cases.push({...record,folder});
 }
 write(path.join(root,'run.json'),{format:'domstride.run',schema_version:1,...run,platform:'web',browser:'chromium',viewport:{width:1280,height:800},status:run.exitCode===0?'passed':run.exitCode===null?'unknown':'failed',cases:cases.map(c=>({folder:c.folder,scenario_id:c.scenario_id,status:c.status,attempt_id:c.attempt_id}))});
 if(run.mode==='documentation'||run.mode==='execution')render(root,docs,spec,cases,run);
}
module.exports={generate};
