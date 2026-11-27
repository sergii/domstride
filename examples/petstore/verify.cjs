const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const base=path.join(__dirname,'artifacts');
const {cropForTarget}=require('./focus-geometry.cjs');
for(const mode of ['fast','execution','documentation']){
 const runs=fs.readdirSync(base).map(dir=>path.join(base,dir)).filter(dir=>fs.existsSync(path.join(dir,'run.json'))).map(dir=>({dir,run:JSON.parse(fs.readFileSync(path.join(dir,'run.json'),'utf8'))})).filter(x=>x.run.mode===mode).sort((a,b)=>a.run.start.localeCompare(b.run.start));
 const {dir,run}=runs.at(-1)||{};
 assert.ok(run,'Missing '+mode);
 assert.equal(run.status,'passed');assert.equal(run.cases.length,4);
 const cases=run.cases.map(c=>({dir:path.join(dir,c.folder),data:JSON.parse(fs.readFileSync(path.join(dir,c.folder,'case.json'),'utf8'))}));
 assert.ok(cases.every(c=>c.data.status==='passed'));
 const positive=cases.find(c=>c.data.scenario_id==='LST-001-01');
 assert.ok(positive);assert.equal(cases.filter(c=>c.data.scenario_id==='LST-001-02').length,3);
 if(mode==='fast'){
  assert.ok(cases.every(c=>c.data.videos.length===0&&c.data.screenshots.length===0&&!fs.existsSync(path.join(c.dir,'capture.json'))));
  assert.ok(!fs.existsSync(path.join(dir,'documentation')));
 }else{
  assert.equal(positive.data.videos[0]?.role,mode==='execution'?'execution':'guided');
  assert.equal(positive.data.videos[0]?.run_id,run.run_id);
  assert.equal(positive.data.videos[0]?.attempt_id,positive.data.attempt_id);
  assert.equal(positive.data.evidence_errors.length,0);
  if(mode==='execution'){assert.equal(positive.data.screenshots.length,0);assert.equal(positive.data.presentation_wait_ms,0);}
  else {assert.ok(positive.data.screenshots.length>=4);assert.ok(positive.data.presentation_wait_ms>0);}
  const capture=JSON.parse(fs.readFileSync(path.join(positive.dir,'capture.json'),'utf8'));
  assert.equal(capture.focus_count,mode==='documentation'?6:0);
  const observations=path.join(positive.dir,'focus-observations.json');
  if(mode==='documentation'){
   const evidence=JSON.parse(fs.readFileSync(observations,'utf8'));
   assert.equal(evidence.timing_quality,'unmapped');
   assert.equal(evidence.outline_color,'#2563eb');
   assert.equal(evidence.targets.length,6);assert.ok(evidence.frames.length>0);
   assert.ok(evidence.recording_window.endMonotonicMs>=evidence.recording_window.startMonotonicMs);
   const stepIds=new Set(positive.data.steps.map(s=>s.runtime_id));
   for(const t of evidence.targets)assert.ok(stepIds.has(t.stepId),'Focus target must map to the actual runtime step');
   for(const [i,f] of evidence.frames.entries())assert.ok(f.sequence===i+1&&f.bytes>0&&Number.isFinite(f.receivedMonotonicMs));
   const candidates=evidence.targets.map(t=>({step_id:t.stepId,action:t.action,observed_monotonic_ms:t.observedMonotonicMs,crop:cropForTarget(t.bounds,t.viewport)}));
   fs.writeFileSync(path.join(positive.dir,'zoom-candidates.json'),JSON.stringify({format:'domstride.reference-zoom-candidates',schema_version:1,timing_quality:'unmapped',candidates},null,2));
  }else assert.ok(!fs.existsSync(observations));
  if(mode==='documentation')assert.equal(fs.readFileSync(path.join(positive.dir,'focus-proof.png')).subarray(0,8).toString('hex'),'89504e470d0a1a0a');
  else assert.ok(!fs.existsSync(path.join(positive.dir,'focus-proof.png')));
  assert.equal(positive.data.videos.length,1);
  for(const s of positive.data.screenshots)assert.equal(fs.readFileSync(path.join(positive.dir,s.file)).subarray(0,8).toString('hex'),'89504e470d0a1a0a');
  assert.equal(fs.readFileSync(path.join(positive.dir,'video-01.webm')).subarray(0,4).toString('hex'),'1a45dfa3');
  assert.ok(cases.filter(c=>c!==positive).every(c=>c.data.videos.length===0));
  const html=fs.readFileSync(path.join(dir,'documentation','LST-001-01.html'),'utf8');
  assert.ok(html.includes('id="group-by"')&&html.includes('id="search"')&&html.includes('navigation-data')&&html.includes('id="video"'));
  assert.ok(html.includes('49.90')&&html.includes('<video'));
  if(mode==='documentation'){
   assert.ok(html.includes('<img')&&html.indexOf('<img')<html.indexOf('<video'));
   assert.ok(html.includes('Guided video (paced)')&&html.includes('Execution video (unpaced)'));
   assert.equal((html.match(/<video /g)||[]).length,2);
   const pair=JSON.parse(fs.readFileSync(path.join(dir,'video-pair.json'),'utf8'));
   assert.notEqual(pair.run_id,run.run_id);assert.notEqual(pair.attempt_id,positive.data.attempt_id);
   assert.ok(fs.existsSync(path.resolve(dir,'documentation',pair.video_path)));
  }else assert.ok(html.includes('Execution video (unpaced)'));
 }
}
console.log('Verified reference artifacts for fast, execution and guided documentation modes');
