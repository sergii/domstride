// Normalize trusted Cucumber Messages without executing tests, reading media or writing files.
const tagId=(tags,prefix)=>tags?.find(t=>t.name.startsWith(prefix))?.name.slice(prefix.length);
const safeId=id=>{if(!/^[a-zA-Z0-9-]+$/.test(id||''))throw new Error('Invalid artifact ID');return id;};
const ms=d=>d==null?null:Number(d.seconds??0)*1000+Number(d.nanos??0)/1e6;
const status=s=>({PASSED:'passed',FAILED:'failed',SKIPPED:'skipped',PENDING:'pending',UNDEFINED:'undefined',AMBIGUOUS:'ambiguous',UNKNOWN:'unknown'}[s]||'unknown');
const outcome=steps=>{
 const values=steps.map(s=>s.status);
 if(values.some(s=>['failed','undefined','ambiguous'].includes(s)))return 'failed';
 if(values.includes('pending'))return 'pending';
 if(values.includes('unknown')||!values.length)return 'unknown';
 if(values.includes('skipped'))return 'skipped';
 return 'passed';
};
function parseMessages(text){
 return text.split(/\r?\n/).flatMap((line,i)=>{
  if(!line.trim())return [];
  try{return [JSON.parse(line)];}catch{throw new Error('Invalid Cucumber Messages JSON at line '+(i+1));}
 });
}
function normalizeMessages(envelopes){
 const all=k=>envelopes.flatMap(e=>e[k]?[e[k]]:[]);
 const docs=all('gherkinDocument').filter(d=>d.feature);
 const spec={format:'domstride.specification',schema_version:1,documents:docs,scenarios:[]};
 const stepsById=new Map(),scenarioById=new Map(),featureIds=new Set(),scenarioIds=new Set();
 function walk(children,feature,rule=null){
  for(const child of children||[]){
   if(child.background)for(const step of child.background.steps)stepsById.set(step.id,{...step,background:true});
   if(child.rule)walk(child.rule.children,feature,child.rule);
   if(child.scenario){
    const s=child.scenario,id=safeId(tagId(s.tags,'@scenario:')),featureId=safeId(tagId(feature.tags,'@feature:'));
    if(scenarioIds.has(id))throw new Error('Duplicate scenario ID');
    scenarioIds.add(id);
    const item={scenario_id:id,feature_id:featureId,feature:feature.name,rule:rule?.name??null,scenario:s};
    spec.scenarios.push(item);scenarioById.set(s.id,item);
    for(const step of s.steps)stepsById.set(step.id,step);
   }
  }
 }
 for(const doc of docs){
  const id=safeId(tagId(doc.feature.tags,'@feature:'));
  if(featureIds.has(id))throw new Error('Duplicate feature ID');
  featureIds.add(id);walk(doc.feature.children,doc.feature);
 }
 const pickles=new Map(all('pickle').map(p=>[p.id,p]));
 const tests=new Map(all('testCase').map(t=>[t.id,t]));
 const resultsByAttempt=new Map(),caseFinished=new Map(),attemptIds=new Set();
 for(const event of all('testStepFinished')){
  if(!resultsByAttempt.has(event.testCaseStartedId))resultsByAttempt.set(event.testCaseStartedId,new Map());
  const results=resultsByAttempt.get(event.testCaseStartedId);
  if(results.has(event.testStepId))throw new Error('Duplicate step result');
  results.set(event.testStepId,event.testStepResult);
 }
 for(const event of all('testCaseFinished'))caseFinished.set(event.testCaseStartedId,event);
 const cases=[];
 for(const start of all('testCaseStarted')){
  const attempt=safeId(start.id);
  if(attemptIds.has(attempt))throw new Error('Duplicate attempt ID');
  attemptIds.add(attempt);
  const test=tests.get(start.testCaseId),pickle=pickles.get(test?.pickleId);
  if(!pickle)throw new Error('Missing test case or pickle for attempt '+attempt);
  const item=pickle.astNodeIds.map(id=>scenarioById.get(id)).find(Boolean);
  if(!item)throw new Error('Missing scenario mapping for attempt '+attempt);
  const results=resultsByAttempt.get(attempt)||new Map();
  const pickleSteps=new Map(pickle.steps.map(step=>[step.id,step]));
  const runtime=test.testSteps.map(step=>{
   const result=results.get(step.id),p=pickleSteps.get(step.pickleStepId);
   if(step.pickleStepId&&!p)throw new Error('Missing pickle step for attempt '+attempt);
   const source=p?.astNodeIds.map(id=>stepsById.get(id)).find(Boolean);
   return {runtime_id:step.id,keyword:source?.keyword?.trim()||(p?'Unknown':'Hook'),text:p?.text??null,
    duration_ms:ms(result?.duration),status:status(result?.status),source_line:source?.location?.line??null,
    source_step_id:source?.id??null,background:source?.background===true,hook:!p,
    ...(p?.argument?{argument:p.argument}:{})};
  });
  const steps=runtime.filter(s=>!s.hook).map((s,i)=>({...s,sequence:i+1}));
  const hooks=runtime.filter(s=>s.hook);
  const complete=caseFinished.has(attempt);
  cases.push({name:pickle.name,status:complete?outcome(runtime):'unknown',
   duration_ms:runtime.every(s=>s.duration_ms!==null)?runtime.reduce((sum,s)=>sum+s.duration_ms,0):null,
   feature_id:item.feature_id,scenario_id:item.scenario_id,attempt_id:attempt,attempt:start.attempt??0,
   source_uri:pickle.uri,example_ast_ids:pickle.astNodeIds.filter(id=>!scenarioById.has(id)),
   steps,hooks,complete,will_be_retried:caseFinished.get(attempt)?.willBeRetried??null});
 }
 return {specification:spec,cases};
}
module.exports={parseMessages,normalizeMessages};
