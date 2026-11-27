// Portable, runner-independent reference model. No Gherkin parsing or test execution here.
const tagValues=(tags,prefix)=>(tags||[]).filter(t=>t.name.startsWith(prefix)).map(t=>t.name.slice(prefix.length));
const stableId=id=>{if(!/^[A-Za-z0-9-]+$/.test(id||''))throw Error('Invalid stable ID');return id;};
// Recognize agreed Gherkin description headings without inventing missing content.
function contextSections(description){
 const sections={overview:[],business_value:[],actors:[],prerequisites:[],other:[]};
 const headings={'overview':'overview','business value':'business_value','actors':'actors','preconditions':'prerequisites','prerequisites':'prerequisites'};
 let current='other';
 for(const line of String(description||'').split(/\r?\n/)){
  const match=line.trim().match(/^(.+):$/);
  if(match&&headings[match[1].toLowerCase()]){current=headings[match[1].toLowerCase()];continue;}
  sections[current].push(line.trim());
 }
 return Object.fromEntries(Object.entries(sections).map(([k,v])=>[k,v.join('\n').trim()]));
}
function classifySteps(steps,sourceSteps){
 let phase='context';
 return steps.map(step=>{
  const source=sourceSteps.get(step.source_step_id);
  const keyword=String(step.keyword||'').trim().toLowerCase();
  // Cucumber keywordType is preferred; conjunctions inherit the previous phase.
  const type=source?.keywordType;
  if(type==='Context'||keyword==='given')phase='context';
  else if(type==='Action'||keyword==='when')phase='action';
  else if(type==='Outcome'||keyword==='then')phase='outcome';
  return {...step,guide_phase:step.background?'setup':phase,source_table:source?.dataTable?.rows||[]};
 });
}
function buildDocumentationModel(spec,cases,run,paired=null){
 const features=spec.documents.map(doc=>{
  const f=doc.feature,featureId=stableId(tagValues(f.tags,'@feature:')[0]);
  const sourceSteps=new Map();
  function visit(children){for(const node of children||[]){for(const s of [...(node.background?.steps||[]),...(node.scenario?.steps||[])])sourceSteps.set(s.id,s);if(node.rule)visit(node.rule.children);}}
  visit(f.children);
  return {id:featureId,name:f.name,description:f.description,context:contextSections(f.description),domains:tagValues(f.tags,'@domain:'),capability:tagValues(f.tags,'@capability:')[0]||'',actors:tagValues(f.tags,'@actor:'),platforms:(f.tags||[]).map(t=>t.name.slice(1)).filter(t=>['web','ios','android'].includes(t)),journeys:tagValues(f.tags,'@journey:'),scenarios:spec.scenarios.filter(s=>s.feature_id===featureId).map(item=>{
   const s=item.scenario,id=stableId(item.scenario_id);
   const attempts=cases.filter(c=>c.scenario_id===id).map(c=>({...c,steps:classifySteps(c.steps,sourceSteps).map(step=>({...step,screenshots:c.screenshots.filter(img=>img.step_sequence===step.sequence)}))}));
   return {id,name:s.name,description:s.description,rule:item.rule,source_steps:s.steps,examples:s.examples||[],attempts,paired_video:paired?.scenario_id===id?paired:null};
  })};
 });
 return {format:'domstride.documentation',schema_version:1,provenance:{run_id:run.run_id,source_sha256:run.source_sha256,application_commit:run.applicationCommit,domstride_commit:run.commit,platform:run.platform,browser:run.browser,viewport:run.viewport,verified_at:run.end,run_status:run.status||(run.exitCode===0?'passed':'failed'),freshness:'historical_run'},features};
}
module.exports={buildDocumentationModel,contextSections,classifySteps};
