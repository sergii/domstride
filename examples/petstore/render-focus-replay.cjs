// Experimental reference viewer. Only conservative visual candidates become seekable.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {focusVtt}=require('./focus-vtt.cjs');
const root=path.resolve(process.argv[2]||'artifacts'),read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const directories=fs.readdirSync(root).flatMap(run=>{
 const dir=path.join(root,run);if(!fs.statSync(dir).isDirectory())return [];
 return fs.readdirSync(dir).filter(n=>/^domstride-case-[A-Za-z0-9-]+$/.test(n)).map(n=>path.join(dir,n));
}).filter(dir=>fs.existsSync(path.join(dir,'focus-media-observations.json')));
assert.equal(directories.length,1);
const dir=directories[0],obs=read(path.join(dir,'focus-media-observations.json')),geometry=read(path.join(dir,'zoom-candidates.json')),c=read(path.join(dir,'case.json'));
assert.equal(obs.timing_quality,'visual_candidates_unvalidated');
assert.equal(c.scenario_id,'LST-001-01');
const labels=['Title','Description','Category','Condition','Price','Publish listing'];
const cues=obs.targets.filter(t=>t.match==='candidate').map(t=>{
 const crop=geometry.candidates.find(g=>g.step_id===t.step_id&&g.action===t.action)?.crop;
 assert.ok(crop);assert.ok(c.steps.some(s=>s.runtime_id===t.step_id));
 assert.ok(Number.isFinite(t.first_visible_pts_ms)&&t.last_visible_pts_ms>=t.first_visible_pts_ms);
 assert.ok(crop.zoom>=1&&crop.zoom<=2.5&&crop.x>=0&&crop.y>=0&&crop.x+crop.width<=1280+1e-8&&crop.y+crop.height<=800+1e-8);
 return {...t,crop,label:labels[t.action-1]||'Action '+t.action};
});
// Attach observed intervals to the original guided manifest only; never invent point cues.
const observations=read(path.join(dir,'focus-observations.json'));
const focus=cues.map(t=>{
 const target=observations.targets.find(g=>g.stepId===t.step_id&&g.action===t.action);
 const step=c.steps.find(s=>s.runtime_id===t.step_id);
 assert.ok(target&&step);
 const {bounds:b,viewport:v}=target;
 const x=Math.max(0,b.x),y=Math.max(0,b.y),right=Math.min(v.width,b.x+b.width),bottom=Math.min(v.height,b.y+b.height);
 assert.ok(right>x&&bottom>y);
 return {kind:t.action===6?'click':[3,4].includes(t.action)?'select':'fill',status:step.status==='passed'?'passed':'unknown',start_ms:t.first_visible_pts_ms,end_ms:t.last_visible_pts_ms,x:x/v.width,y:y/v.height,width:(right-x)/v.width,height:(bottom-y)/v.height,step_sequence:step.sequence,label:t.label,...(target.transition==='navigation'&&t.action===6?{transition:'navigation'}:{})};
});
assert.equal(c.videos.length,1);assert.equal(c.videos[0].role,'guided');
c.videos[0].timing_quality='visual_candidates_unvalidated';c.videos[0].focus=focus;
fs.writeFileSync(path.join(dir,'case.json'),JSON.stringify(c,null,2)+'\n');
const captions=focusVtt(cues);
fs.writeFileSync(path.join(dir,'focus-captions.vtt'),captions);
fs.writeFileSync(path.join(dir,'focus-chapters.vtt'),captions);
const data={attempt_id:c.attempt_id,source:path.basename(path.dirname(dir)),timing_quality:obs.timing_quality,viewport:{width:1280,height:800},steps:c.steps,cues,captions};
const html=fs.readFileSync(path.join(__dirname,'focus-replay-template.html'),'utf8').replace('__VIDEO__',()=> 'data:video/webm;base64,'+fs.readFileSync(path.join(dir,'video-01.webm')).toString('base64')).replace('__MODEL__',()=>JSON.stringify(data).replace(/</g,'\\u003c'));
fs.writeFileSync(path.join(dir,'focus-replay.html'),html);
console.log('Generated focus replay with '+cues.length+' candidate actions; no timing inferred for other steps.');
