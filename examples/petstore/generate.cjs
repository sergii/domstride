// Reference exporter for trusted synthetic runs; not the production protocol validator.
const fs=require('node:fs');
const {render}=require('./render-docs.cjs');
const path=require('node:path');
const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const tagId=(tags,prefix)=>tags?.find(t=>t.name.startsWith(prefix))?.name.slice(prefix.length);
const safeId=id=>{if(!/^[a-zA-Z0-9-]+$/.test(id||''))throw new Error('Invalid artifact ID');return id;};
const write=(file,data)=>fs.writeFileSync(file,JSON.stringify(data,null,2)+'\n');
const ms=d=>Number(d?.seconds??0)*1000+Number(d?.nanos??0)/1e6;
const status=s=>({PASSED:'passed',FAILED:'failed',SKIPPED:'skipped',PENDING:'pending',UNDEFINED:'undefined',AMBIGUOUS:'ambiguous',UNKNOWN:'unknown'}[s]||'unknown');
const outcome=steps=>{
 const values=steps.map(s=>s.status);
 if(values.some(s=>['failed','undefined','ambiguous'].includes(s)))return 'failed';
 if(values.includes('pending'))return 'pending';
 if(values.includes('unknown')||!values.length)return 'unknown';
 if(values.includes('skipped'))return 'skipped';
 return 'passed';
};
function generate(root,run){
 const envelopes=fs.readFileSync(path.join(root,'messages.ndjson'),'utf8').split(/\r?\n/).filter(Boolean).map(JSON.parse);
 const all=k=>envelopes.flatMap(e=>e[k]?[e[k]]:[]);
 const docs=all('gherkinDocument').filter(d=>d.feature);
 const spec={format:'domstride.specification',schema_version:1,documents:docs,scenarios:[]};
 const stepsById=new Map(),scenarioById=new Map();
 function walk(children,feature,rule=null){
  for(const child of children||[]){
   if(child.background)for(const step of child.background.steps)stepsById.set(step.id,{...step,background:true});
   if(child.rule)walk(child.rule.children,feature,child.rule);
   if(child.scenario){
    const s=child.scenario,id=safeId(tagId(s.tags,'@scenario:')),featureId=safeId(tagId(feature.tags,'@feature:'));
    if(spec.scenarios.some(x=>x.scenario_id===id))throw new Error('Duplicate scenario ID');
    const item={scenario_id:id,feature_id:featureId,feature:feature.name,rule:rule?.name??null,scenario:s};
    spec.scenarios.push(item);scenarioById.set(s.id,item);
    for(const step of s.steps)stepsById.set(step.id,step);
   }
  }
 }
 for(const doc of docs)walk(doc.feature.children,doc.feature);
 write(path.join(root,'specification.json'),spec);
 const pickles=new Map(all('pickle').map(p=>[p.id,p]));
 const tests=new Map(all('testCase').map(t=>[t.id,t]));
 const finished=all('testStepFinished'),caseFinished=new Set(all('testCaseFinished').map(e=>e.testCaseStartedId));
 const cases=[];
 for(const start of all('testCaseStarted')){
  const attempt=safeId(start.id),test=tests.get(start.testCaseId),pickle=pickles.get(test?.pickleId);
  if(!pickle)continue;
  const item=pickle.astNodeIds.map(id=>scenarioById.get(id)).find(Boolean);
  if(!item)continue;
  const folder='domstride-case-'+attempt,dir=path.join(root,folder);
  fs.mkdirSync(dir,{recursive:true});
  const capturePath=path.join(dir,'capture.json');
  const capture=fs.existsSync(capturePath)?JSON.parse(fs.readFileSync(capturePath,'utf8')):{screenshots:[],video:null,errors:[]};
  const results=new Map(finished.filter(x=>x.testCaseStartedId===attempt).map(x=>[x.testStepId,x.testStepResult]));
  const runtime=[];
  for(const step of test.testSteps){
   const result=results.get(step.id);
   const p=pickle.steps.find(x=>x.id===step.pickleStepId);
   const source=p?.astNodeIds.map(id=>stepsById.get(id)).find(Boolean);
   runtime.push({runtime_id:step.id,keyword:source?.keyword?.trim()||'Hook',text:p?.text??null,
    duration_ms:ms(result?.duration),status:status(result?.status),source_line:source?.location?.line??null,
    source_step_id:source?.id??null,background:source?.background===true,hook:!p});
  }
  const steps=runtime.filter(s=>!s.hook).map((s,i)=>({...s,sequence:i+1}));
  const screenshots=(capture.screenshots||[]).filter(s=>/^screenshots\/step-\d{3}\.png$/.test(s.file)&&fs.existsSync(path.join(dir,s.file))).flatMap(s=>{
   const step=steps.find(t=>t.runtime_id===s.stepId);
   return step?[{file:s.file,step_sequence:step.sequence,source_step_id:step.source_step_id,phase:'after',url:s.url}]:[];
  });
  const video=capture.video==='video-01.webm'&&fs.existsSync(path.join(dir,'video-01.webm'));
  const record={format:'domstride.case',schema_version:1,name:pickle.name,status:caseFinished.has(attempt)?outcome(runtime):'unknown',
   duration_ms:runtime.reduce((sum,s)=>sum+s.duration_ms,0),producer:'living-documentation-reference',framework:'cucumber-js',runner:'playwright',platform:'web',language:'typescript',
   feature_id:item.feature_id,scenario_id:item.scenario_id,attempt_id:attempt,attempt:start.attempt??0,source_uri:pickle.uri,example_ast_ids:pickle.astNodeIds.filter(id=>!scenarioById.has(id)),
   steps,screenshots,videos:video?[{file:'video-01.webm',label:'Chromium',role:capture.profile,attempt_id:attempt,run_id:run.run_id}]:[],presentation_wait_ms:capture.presentation_wait_ms??0,evidence_errors:capture.errors||[],timing_quality:'unmapped'};
  write(path.join(dir,'case.json'),record);
  cases.push({...record,folder});
 }
 write(path.join(root,'run.json'),{format:'domstride.run',schema_version:1,...run,platform:'web',browser:'chromium',viewport:{width:1280,height:800},status:run.exitCode===0?'passed':run.exitCode===null?'unknown':'failed',cases:cases.map(c=>({folder:c.folder,scenario_id:c.scenario_id,status:c.status,attempt_id:c.attempt_id}))});
 if(run.mode==='documentation'||run.mode==='execution')render(root,docs,spec,cases,run);
}
module.exports={generate};
