// Reference exporter for trusted synthetic runs; not the production protocol validator.
const fs=require('node:fs');
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
   steps,screenshots,videos:video?[{file:'video-01.webm',label:'Chromium'}]:[],evidence_errors:capture.errors||[],timing_quality:'unmapped'};
  write(path.join(dir,'case.json'),record);
  cases.push({...record,folder});
 }
 write(path.join(root,'run.json'),{format:'domstride.run',schema_version:1,...run,platform:'web',browser:'chromium',viewport:{width:1280,height:800},status:run.exitCode===0?'passed':run.exitCode===null?'unknown':'failed',cases:cases.map(c=>({folder:c.folder,scenario_id:c.scenario_id,status:c.status,attempt_id:c.attempt_id}))});
 if(run.mode==='documentation')render(root,docs,spec,cases,run);
}
function table(rows){
 return rows?.length?'<table>'+rows.map(r=>'<tr>'+r.cells.map(c=>'<td>'+esc(c.value)+'</td>').join('')+'</tr>').join('')+'</table>':'';
}
function description(text){
 return esc(text).split(/\n\s*\n/).filter(x=>x.trim()).map(p=>{
  const lines=p.trim().split('\n');
  if(lines[0].trim().endsWith(':'))return '<h3>'+lines.shift().trim().slice(0,-1)+'</h3><p class="description">'+lines.join('\n').trim()+'</p>';
  return '<p class="description">'+p.trim()+'</p>';
 }).join('');
}
function render(root,docs,spec,cases,run){
 const dir=path.join(root,'documentation');fs.mkdirSync(dir,{recursive:true});
 const css='*{box-sizing:border-box}body{font:16px/1.65 system-ui;color:#20352d;background:#f5f8f6;margin:0}main{max-width:900px;margin:auto;padding:38px 24px}h1,h2,h3{line-height:1.25;color:#133b2d}h1{font-size:36px}h2{margin-top:32px}a{color:#047857}header,article,section{background:#fff;border:1px solid #d9e6df;padding:24px;margin:16px 0;border-radius:12px}.eyebrow{font-size:13px;color:#587267;text-transform:uppercase;letter-spacing:.06em}.description{white-space:pre-line}.meta{color:#526c61;font-size:14px}.passed{color:#047857}.failed{color:#b91c1c}figure{margin:18px 0}img,video{display:block;width:100%;height:auto;border:1px solid #d9e6df;border-radius:8px}figcaption{font-size:13px;color:#526c61}li{margin:12px 0}td{padding:5px 12px;border:1px solid #d9e6df}table{border-collapse:collapse;margin:12px 0}summary{cursor:pointer}footer{margin-top:30px;color:#526c61;font-size:13px}';
 const page=(title,body)=>'<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>'+esc(title)+'</title><style>'+css+'</style></head><body><main><div class="eyebrow">Domstride Docs / Reference example</div>'+body+'<footer>Generated from Gherkin and actual Petstore Rails run evidence with synthetic test data. Web / Chromium.</footer></main></body></html>';
 const features=[];
 for(const doc of docs){
  const f=doc.feature,id=safeId(tagId(f.tags,'@feature:')),items=spec.scenarios.filter(s=>s.feature_id===id);
  features.push('<li><a href="'+id+'.html">'+esc(f.name)+'</a></li>');
  const links=items.map(s=>'<li><a href="'+s.scenario_id+'.html">'+esc(s.scenario.name)+'</a> <span class="meta">'+esc(s.rule||'')+'</span></li>').join('');
  fs.writeFileSync(path.join(dir,id+'.html'),page(f.name,'<a href="index.html">All features</a><header><div class="eyebrow">'+id+'</div><h1>'+esc(f.name)+'</h1>'+description(f.description)+'<p class="meta">Declared applicability: '+esc(f.tags.map(t=>t.name).join(' '))+'; actual execution: Web / Chromium</p></header><section><h2>Scenarios</h2><ul>'+links+'</ul></section>'));
  for(const item of items){
   const s=item.scenario,matched=cases.filter(c=>c.scenario_id===item.scenario_id);
   const stepBlock=(step,c)=>{
    const source=s.steps.find(x=>x.id===step.source_step_id);
    const images=c.screenshots.filter(x=>x.step_sequence===step.sequence).map(img=>'<figure><img loading="lazy" src="../'+c.folder+'/'+img.file+'" alt="'+esc(step.text)+'"><figcaption>'+esc(step.text)+' · actual screenshot · '+esc(img.url)+'</figcaption></figure>').join('');
    return '<li><strong>'+esc(step.keyword)+' '+esc(step.text)+'</strong> <span class="'+step.status+'">'+esc(step.status)+'</span>'+table(source?.dataTable?.rows)+images+'</li>';
   };
   const execution=matched.map(c=>{
    const setup=c.steps.filter(x=>x.background),body=c.steps.filter(x=>!x.background);
    const firstThen=body.findIndex(x=>x.keyword==='Then');
    const walkthrough=firstThen<0?body:body.slice(0,firstThen),expected=firstThen<0?[]:body.slice(firstThen);
    return '<article><h2>Execution: '+esc(c.name)+'</h2><p class="'+c.status+'">Actual outcome: '+esc(c.status)+'</p><p class="meta">Attempt '+esc(c.attempt+1)+' · '+esc(c.duration_ms.toFixed(1))+' ms · Web / Chromium</p>'
      +(setup.length?'<details><summary>Background / setup</summary><ol>'+setup.map(x=>stepBlock(x,c)).join('')+'</ol></details>':'')
      +'<h3>Walkthrough</h3><ol>'+walkthrough.map(x=>stepBlock(x,c)).join('')+'</ol>'
      +(expected.length?'<h3>Expected results and actual verification</h3><ol>'+expected.map(x=>stepBlock(x,c)).join('')+'</ol>':'')
      +(c.evidence_errors.length?'<p>Some capture evidence is unavailable.</p>':'')
      +'<h3>Video walkthrough</h3>'+(c.videos.length?'<video controls preload="metadata" src="../'+c.folder+'/video-01.webm"></video><p class="meta">Recorded video; precise step synchronization not calibrated.</p>':'<p>No video recorded for this attempt.</p>')+'</article>';
   }).join('');
   const examples=(s.examples||[]).map(e=>'<h3>Examples '+esc(e.name)+'</h3>'+table([e.tableHeader,...e.tableBody].filter(Boolean))).join('');
   const related=items.filter(x=>x!==item).map(x=>'<li><a href="'+x.scenario_id+'.html">'+esc(x.scenario.name)+'</a></li>').join('');
   fs.writeFileSync(path.join(dir,item.scenario_id+'.html'),page(s.name,'<a href="'+id+'.html">'+esc(f.name)+'</a><header><div class="eyebrow">'+item.scenario_id+'</div><h1>'+esc(s.name)+'</h1>'+description(s.description)+'<h3>Business rule</h3><p>'+esc(item.rule||'Not specified')+'</p><p class="meta">Specification / application commit: '+esc(run.applicationCommit||'not supplied')+' · Run: '+esc(run.start)+' · declared platforms are not verification.</p></header>'
    +(execution||'<section><p>Unverified: no recorded execution.</p><ol>'+s.steps.map(x=>'<li>'+esc(x.keyword+x.text)+table(x.dataTable?.rows)+'</li>').join('')+'</ol></section>')
    +(examples?'<section>'+examples+'</section>':'')+(related?'<section><h2>Related scenarios</h2><ul>'+related+'</ul></section>':'')));
  }
 }
 fs.writeFileSync(path.join(dir,'index.html'),page('Living documentation','<header><h1>Living documentation</h1><p>Executable specifications and actual verification evidence.</p><p class="meta">Run status: '+esc(run.exitCode===0?'passed':'not passed')+'</p></header><section><h2>Features</h2><ul>'+features.join('')+'</ul></section>'));
}
module.exports={generate};
