// Pair two independently verified recordings without mixing their execution evidence.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {render}=require('./render-docs.cjs');
const base=path.join(__dirname,'artifacts');
const load=(file)=>JSON.parse(fs.readFileSync(file,'utf8'));
const latest=(mode)=>{
 const found=fs.readdirSync(base).map(name=>path.join(base,name)).filter(dir=>fs.existsSync(path.join(dir,'run.json'))).map(dir=>({dir,run:load(path.join(dir,'run.json'))})).filter(x=>x.run.mode===mode).sort((a,b)=>a.run.start.localeCompare(b.run.start)).at(-1);
 assert.ok(found,'Missing '+mode+' run');
 assert.equal(found.run.status,'passed');
 return found;
};
const guided=latest('documentation'),execution=latest('execution');
for(const key of ['source_sha256','applicationCommit','commit','platform','browser']){
 assert.ok(guided.run[key],'Missing provenance: '+key);
 assert.equal(guided.run[key],execution.run[key],'Mismatched provenance: '+key);
}
assert.deepEqual(guided.run.viewport,execution.run.viewport);
assert.notEqual(guided.run.run_id,execution.run.run_id);
const casesFor=x=>x.run.cases.map(c=>({...load(path.join(x.dir,c.folder,'case.json')),folder:c.folder}));
const g=casesFor(guided),e=casesFor(execution);
const selected=c=>c.filter(x=>x.videos.length);
assert.equal(selected(g).length,1);assert.equal(selected(e).length,1);
const gv=selected(g)[0],ev=selected(e)[0];
assert.equal(gv.scenario_id,ev.scenario_id);assert.equal(gv.status,'passed');assert.equal(ev.status,'passed');
assert.notEqual(gv.attempt_id,ev.attempt_id);assert.equal(gv.videos[0].role,'guided');assert.equal(ev.videos[0].role,'execution');
assert.equal(ev.presentation_wait_ms,0);assert.ok(gv.presentation_wait_ms>0);
const docDir=path.join(guided.dir,'documentation');
const relative=p=>path.relative(docDir,p).split(path.sep).join('/');
const manifest={format:'domstride.reference-video-pair',schema_version:1,scenario_id:ev.scenario_id,run_id:execution.run.run_id,attempt_id:ev.attempt_id,guided_run_id:guided.run.run_id,guided_attempt_id:gv.attempt_id,video_path:relative(path.join(execution.dir,ev.folder,ev.videos[0].file)),report_path:relative(path.join(execution.dir,'documentation',ev.scenario_id+'.html'))};
for(const p of [manifest.video_path,manifest.report_path])assert.ok(fs.existsSync(path.resolve(docDir,p)));
const spec=load(path.join(guided.dir,'specification.json'));
render(guided.dir,spec.documents,spec,g,guided.run,manifest);
fs.writeFileSync(path.join(guided.dir,'video-pair.json'),JSON.stringify(manifest,null,2)+'\n');
console.log('Paired independently verified execution and guided recordings: '+ev.scenario_id);
