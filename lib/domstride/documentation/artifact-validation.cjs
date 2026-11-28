// Structural and cross-reference checks for the local documentation run profile.
const fail=(p,m)=>{throw Error('Invalid artifact '+p+': '+m);};
const check=(v,p,m)=>{if(!v)fail(p,m);};
const object=(v,p)=>check(v!==null&&typeof v==='object'&&!Array.isArray(v),p,'expected object');
const id=(v,p)=>check(typeof v==='string'&&/^[A-Za-z0-9-]{1,128}$/.test(v),p,'invalid identifier');
const text=(v,p,max=1024)=>check(typeof v==='string'&&v.length>0&&Buffer.byteLength(v)<=max,p,'invalid text');
const array=(v,p,max)=>check(Array.isArray(v)&&v.length<=max,p,'invalid array or limit exceeded');
const duration=(v,p)=>check(Number.isFinite(v)&&v>=0,p,'invalid duration');
const header=(v,format,p)=>{object(v,p);check(v.format===format&&v.schema_version===1,p,'unsupported format/version');};
const statuses=['passed','failed','skipped','pending','unknown'];
const status=(v,p)=>check(statuses.includes(v),p,'invalid status');
function unique(set,v,p){check(!set.has(v),p,'duplicate identity');set.add(v);}
function validateSpecification(spec){
 header(spec,'domstride.specification','specification');array(spec.documents,'documents',100);array(spec.scenarios,'scenarios',1000);
 const features=new Set(),scenarios=new Map();
 for(const d of spec.documents){
  object(d,'document');object(d.feature,'feature');
  array(d.feature.tags,'feature.tags',100);const tags=d.feature.tags.filter(t=>typeof t?.name==='string'&&t.name.startsWith('@feature:'));
  check(tags.length===1,'feature.tags','exactly one feature ID required');
  const featureId=tags[0].name.slice(9);id(featureId,'feature.id');unique(features,featureId,'feature.id');
 }
 for(const s of spec.scenarios){
  object(s,'scenario entry');id(s.scenario_id,'scenario.id');id(s.feature_id,'scenario.feature_id');
  check(features.has(s.feature_id),'scenario.feature_id','unknown feature');
  check(!scenarios.has(s.scenario_id),'scenario.id','duplicate identity');
  object(s.scenario,'scenario AST');text(s.scenario.name,'scenario.name');array(s.scenario.steps,'scenario.steps',100);
  scenarios.set(s.scenario_id,s.feature_id);
 }
 return scenarios;
}
function validateRun(run){
 header(run,'domstride.run','run');id(run.run_id,'run.id');status(run.status,'run.status');
 check(['fast','execution','documentation'].includes(run.mode),'run.mode','invalid mode');
 array(run.cases,'run.cases',100);const attempts=new Set(),folders=new Set();
 for(const c of run.cases){
  object(c,'run case');id(c.folder,'case.folder');id(c.attempt_id,'case.attempt_id');id(c.scenario_id,'case.scenario_id');status(c.status,'case.status');
  unique(attempts,c.attempt_id,'case.attempt_id');unique(folders,c.folder,'case.folder');
 }
}
function validateDocumentationCase(c,run,entry,scenarios){
 header(c,'domstride.case','case');text(c.name,'case.name');status(c.status,'case.status');duration(c.duration_ms,'case.duration_ms');
 for(const k of ['attempt_id','scenario_id','status'])check(c[k]===entry[k],'case.'+k,'run entry mismatch');
 check(scenarios.has(c.scenario_id)&&scenarios.get(c.scenario_id)===c.feature_id,'case.feature_id','unknown or mismatched specification');
 array(c.steps,'case.steps',100);const runtimeIds=new Set();
 for(const [i,s] of c.steps.entries()){
  object(s,'step');check(s.sequence===i+1,'step.sequence','non-contiguous sequence');
  id(s.runtime_id,'step.runtime_id');unique(runtimeIds,s.runtime_id,'step.runtime_id');
  check(typeof s.keyword==='string'&&s.keyword.length<=64,'step.keyword','invalid keyword');
  check(s.text===null||(typeof s.text==='string'&&s.text.length<=1030),'step.text','invalid text');
  check([...statuses,'undefined','ambiguous'].includes(s.status),'step.status','invalid status');duration(s.duration_ms,'step.duration_ms');
 }
 array(c.screenshots,'case.screenshots',100);const screenshots=new Set();
 for(const s of c.screenshots){
  object(s,'screenshot');check(typeof s.file==='string'&&/^screenshots\/step-\d{3}\.png$/.test(s.file),'screenshot.file','invalid local filename');
  unique(screenshots,s.file,'screenshot.file');check(Number.isInteger(s.step_sequence)&&s.step_sequence>=1&&s.step_sequence<=c.steps.length,'screenshot.step_sequence','unknown step');
  check(s.phase==='after','screenshot.phase','unsupported phase');
 }
 array(c.videos,'case.videos',4);const videos=new Set();
 for(const [i,v] of c.videos.entries()){
  object(v,'video');check(v.file==='video-0'+(i+1)+'.webm','video.file','invalid ordered filename');unique(videos,v.file,'video.file');
  text(v.label,'video.label',128);check(v.run_id===run.run_id&&v.attempt_id===c.attempt_id,'video.provenance','run/attempt mismatch');
  check(v.role===(run.mode==='documentation'?'guided':'execution')&&run.mode!=='fast','video.role','mode mismatch');
 }
 array(c.evidence_errors,'case.evidence_errors',100);
 check(c.evidence_errors.every(e=>typeof e==='string'),'case.evidence_errors','expected strings');
 if(run.mode==='fast')check(!c.videos.length&&!c.screenshots.length,'case.media','fast mode must not capture');
 if(run.mode==='execution')check(!c.screenshots.length,'case.screenshots','execution mode must not capture screenshots');
}
function validateDocumentationRun(spec,run,cases){
 const scenarios=validateSpecification(spec);validateRun(run);array(cases,'cases',100);
 check(cases.length===run.cases.length,'cases','run/case count mismatch');
 const byFolder=new Map();
 for(const c of cases){object(c,'case');check(!byFolder.has(c.folder),'case.folder','duplicate folder');byFolder.set(c.folder,c);}
 for(const entry of run.cases){const c=byFolder.get(entry.folder);check(c,'case.folder','missing case');validateDocumentationCase(c,run,entry,scenarios);}
}
module.exports={validateSpecification,validateRun,validateDocumentationRun};
