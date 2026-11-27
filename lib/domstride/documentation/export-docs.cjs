// Local export for explicitly approved, trusted synthetic evidence only.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {buildDocumentationModel}=require('./documentation-model.cjs');
// Reject symlinks in the artifact tree; the caller must control the run directory.
function readRegular(p){
 const absolute=path.resolve(p);
 let current=absolute;
 while(true){
  assert.ok(!fs.lstatSync(current).isSymbolicLink(),'Symlink is not an approved artifact path: '+current);
  const parent=path.dirname(current);if(parent===current)break;current=parent;
 }
 assert.ok(fs.lstatSync(absolute).isFile(),'Expected a regular artifact file');
 return fs.readFileSync(absolute);
}
const load=p=>JSON.parse(readRegular(p).toString('utf8'));
const safe=id=>{assert.match(id,/^[A-Za-z0-9-]+$/);return id;};
const plain=s=>String(s??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\{/g,'&#123;').replace(/\}/g,'&#125;').replace(/([\\`*_[\]|])/g,'\\$1');
const output=(p,v)=>fs.writeFileSync(p,v);
function exportDocs(root,{syntheticReference=false}={}){
 assert.equal(syntheticReference,true,'Explicit synthetic-reference approval required');
 root=path.resolve(root);const run=load(path.join(root,'run.json')),spec=load(path.join(root,'specification.json'));
 assert.equal(run.mode,'documentation');assert.equal(run.status,'passed');
 assert.equal(run.format,'domstride.run');assert.equal(run.schema_version,1);
 assert.equal(spec.format,'domstride.specification');assert.equal(spec.schema_version,1);
 assert.equal(run.platform,'web');assert.equal(run.browser,'chromium');
 assert.ok(run.cases.length);assert.ok(spec.scenarios.length);
 const ids=spec.scenarios.map(s=>safe(s.scenario_id));assert.equal(new Set(ids).size,ids.length,'Duplicate scenario ID');
 const cases=run.cases.map(c=>({...load(path.join(root,safe(c.folder),'case.json')),folder:c.folder}));
 assert.ok(cases.every(c=>c.status==='passed'&&c.evidence_errors.length===0));
 const paired=load(path.join(root,'video-pair.json'));
 const executionRoot=path.join(path.dirname(root),safe(paired.run_id)),executionRun=load(path.join(executionRoot,'run.json'));
 for(const key of ['source_sha256','applicationCommit','commit','platform','browser']){assert.ok(run[key]);assert.equal(run[key],executionRun[key]);}
 assert.deepEqual(run.viewport,executionRun.viewport);assert.equal(executionRun.status,'passed');assert.equal(executionRun.mode,'execution');
 assert.equal(paired.guided_run_id,run.run_id);assert.notEqual(paired.run_id,run.run_id);
 const ref=executionRun.cases.find(c=>c.attempt_id===paired.attempt_id);assert.ok(ref);
 const ec=load(path.join(executionRoot,safe(ref.folder),'case.json'));
 assert.equal(ec.scenario_id,paired.scenario_id);assert.equal(ec.status,'passed');assert.equal(ec.videos[0].role,'execution');assert.equal(ec.videos[0].file,'video-01.webm');assert.equal(ec.videos[0].run_id,executionRun.run_id);assert.equal(ec.videos[0].attempt_id,ec.attempt_id);
 const g=cases.find(c=>c.attempt_id===paired.guided_attempt_id);assert.ok(g);assert.equal(g.scenario_id,ec.scenario_id);assert.equal(g.videos[0].role,'guided');assert.equal(g.videos[0].run_id,run.run_id);assert.equal(g.videos[0].attempt_id,g.attempt_id);
 const model=buildDocumentationModel(spec,cases,run,paired),dir=path.join(root,'static-export');
 // A generated directory must not contain authored or unrelated files.
 if(fs.existsSync(dir))throw Error('Export directory already exists; use a new run or remove the generated export explicitly.');
 for(const d of ['markdown','mdx','media'])fs.mkdirSync(path.join(dir,d),{recursive:true});
 const media=[],written=new Set();
 function copy(source,filename,meta,magic){
  assert.ok(!written.has(filename),'Duplicate media filename: '+filename);written.add(filename);
  const file=readRegular(source);assert.equal(file.subarray(0,magic.length/2).toString('hex'),magic);
  output(path.join(dir,'media',filename),file);
  media.push({file:'media/'+filename,sha256:crypto.createHash('sha256').update(file).digest('hex'),size_bytes:file.length,...meta});
  return '../media/'+filename;
 }
 const pages=[];
 for(const f of model.features)for(const s of f.scenarios){
  const lines=['# '+plain(s.name),'',plain(s.description||''),'','Verified historical behavior (Web / Chromium). Current freshness is not asserted.',''];
  const sections=[['Overview',f.context.overview],['Business value',f.context.business_value],['Actors',f.context.actors],['Prerequisites',f.context.prerequisites],['Additional context',f.context.other],['Business rule',s.rule]];
  for(const [label,value] of sections)if(value){lines.push('## '+label,'',...String(value).split('\n').map(line=>line.startsWith('- ')?'- '+plain(line.slice(2)):plain(line)),'');}
  const videoLinks=[],technical=['<details>','<summary>Technical details and verification</summary>','','Specification: '+s.id,'','Application commit: '+plain(run.applicationCommit),'','Domstride commit: '+plain(run.commit),'','Run ID: '+plain(run.run_id),'','Verified at: '+plain(run.end),'','Source SHA-256: '+plain(run.source_sha256),''];
  for(const a of s.attempts){
   if(s.attempts.length>1)lines.push('## Example '+(s.attempts.indexOf(a)+1),'');
   lines.push('Actual outcome: '+a.status+'.','');
   technical.push('**Attempt '+plain(a.attempt_id)+'** ('+a.status+', '+a.duration_ms.toFixed(1)+' ms)','','Original executed steps (including setup):','',...a.steps.map(st=>'- '+plain(st.keyword+' '+st.text)+' ('+st.status+')'),'');
   let previous=null,i=0;
   for(const st of a.steps.filter(st=>!st.background)){
    if(st.guide_phase!==previous){
     lines.push('### '+({context:'Initial context',action:'Walkthrough',outcome:'Expected results'}[st.guide_phase]||'Other steps'),'');
     previous=st.guide_phase;i=0;
    }
    lines.push(st.guide_phase==='action'?'#### '+(++i)+'. '+plain(st.text):'**'+plain(st.text)+'**','');
    if(st.guide_phase==='outcome')lines.push('Verification: '+st.status+'.','');
    if(st.source_table.length){
     const width=st.source_table[0].cells.length;
     lines.push('| '+Array.from({length:width},(_,i)=>width===2?['Field','Value'][i]:'Column '+(i+1)).join(' | ')+' |','| '+Array.from({length:width},()=> '---').join(' | ')+' |');
     for(const row of st.source_table)lines.push('| '+row.cells.map(c=>plain(c.value)).join(' | ')+' |');lines.push('');
    }
    for(const img of st.screenshots){
     assert.match(img.file,/^screenshots\/step-\d{3}\.png$/);
     const name=s.id+'-'+safe(a.attempt_id)+'-'+path.basename(img.file);
     const uri=copy(path.join(root,safe(a.folder),img.file),name,{kind:'screenshot',run_id:run.run_id,attempt_id:a.attempt_id,scenario_id:s.id,step_sequence:st.sequence},'89504e470d0a1a0a');
     lines.push('!['+plain(st.text)+']('+uri+')','','Actual screenshot after this step.','');
    }
   }
   for(const v of a.videos){assert.equal(v.file,'video-01.webm');assert.equal(v.role,'guided');const uri=copy(path.join(root,safe(a.folder),v.file),s.id+'-guided.webm',{kind:'video',role:'guided',run_id:run.run_id,attempt_id:a.attempt_id,scenario_id:s.id},'1a45dfa3');videoLinks.push({title:'Guided video (paced)',uri});}
  }
  technical.push('</details>','');
  if(s.id===ec.scenario_id){const uri=copy(path.join(executionRoot,safe(ref.folder),'video-01.webm'),s.id+'-execution.webm',{kind:'video',role:'execution',run_id:executionRun.run_id,attempt_id:ec.attempt_id,scenario_id:s.id},'1a45dfa3');videoLinks.push({title:'Execution video (unpaced)',uri});}
  if(s.examples.length){lines.push('## Examples','');for(const e of s.examples){if(!e.tableHeader)continue;lines.push('| '+e.tableHeader.cells.map(c=>plain(c.value)).join(' | ')+' |','| '+e.tableHeader.cells.map(()=> '---').join(' | ')+' |');for(const row of e.tableBody)lines.push('| '+row.cells.map(c=>plain(c.value)).join(' | ')+' |');lines.push('');}}
  const related=f.scenarios.filter(x=>x.id!==s.id);
  if(related.length)lines.push('## Related scenarios','',...related.map(x=>'- ['+plain(x.name)+']('+x.id+'.mdx)'),'');
  lines.push(...technical,'## Video walkthrough','');
  const md=lines.map(line=>line.replace(/\]\(([A-Za-z0-9-]+)\.mdx\)/g,']($1.md)')).concat(videoLinks.length?videoLinks.map(v=>'['+v.title+']('+v.uri+')'):['No video recorded.']).join('\n')+'\n';
  const mdx=lines.concat(videoLinks.length?videoLinks.flatMap(v=>['### '+v.title,'','<video controls playsInline preload="metadata" src="'+v.uri+'" />','']):['No video recorded.']).join('\n')+'\n';
  output(path.join(dir,'markdown',s.id+'.md'),md);output(path.join(dir,'mdx',s.id+'.mdx'),mdx);pages.push({id:s.id,title:s.name,markdown:'markdown/'+s.id+'.md',mdx:'mdx/'+s.id+'.mdx'});
 }
 output(path.join(dir,'manifest.json'),JSON.stringify({format:'domstride.reference-publication',schema_version:1,provenance:model.provenance,pages,media},null,2)+'\n');
 // The full internal model stays outside the media-only export.
 output(path.join(root,'documentation-model.json'),JSON.stringify(model,null,2)+'\n');
 console.log('Exported '+pages.length+' static guides and '+media.length+' approved media assets.');
 return dir;
}
if(require.main===module){assert.equal(process.argv[2],'--synthetic-reference','Explicit synthetic-reference export required');assert.ok(process.argv[3],'Provide exact guided run directory');assert.equal(process.argv.length,4,'Expected exactly one run directory');exportDocs(process.argv[3],{syntheticReference:true});}
module.exports={exportDocs};
