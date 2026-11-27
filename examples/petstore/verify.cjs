const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const base=path.join(__dirname,'artifacts');
for(const mode of ['fast','documentation']){
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
  assert.ok(positive.data.screenshots.length>=4);
  assert.equal(positive.data.videos.length,1);
  for(const s of positive.data.screenshots)assert.equal(fs.readFileSync(path.join(positive.dir,s.file)).subarray(0,8).toString('hex'),'89504e470d0a1a0a');
  assert.equal(fs.readFileSync(path.join(positive.dir,'video-01.webm')).subarray(0,4).toString('hex'),'1a45dfa3');
  assert.ok(cases.filter(c=>c!==positive).every(c=>c.data.videos.length===0));
  const html=fs.readFileSync(path.join(dir,'documentation','LST-001-01.html'),'utf8');
  assert.ok(html.includes('49.90')&&html.includes('<img')&&html.includes('<video')&&html.indexOf('<img')<html.indexOf('<video'));
 }
}
console.log('Verified reference artifacts for fast and documentation modes');
