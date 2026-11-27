// Materialize an approved synthetic reference publication into Starlight.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
function importPublication({site,input,target}){
assert.ok(['starlight','fumadocs'].includes(target));
const isFuma=target==='fumadocs';
assert.ok(input,'Provide the exact static-export directory');
const root=path.resolve(input),manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'),'utf8'));
assert.equal(manifest.format,'domstride.reference-publication');assert.equal(manifest.schema_version,1);
assert.equal(manifest.provenance.run_status,'passed');
const runId=manifest.provenance.run_id;
assert.match(runId,/^[A-Za-z0-9-]+$/);
const content=path.join(site,isFuma?'content/docs/generated':'src/content/docs/generated'),assets=path.join(site,'public/domstride-media',runId);
assert.ok(!fs.existsSync(content),'Generated content exists; remove it explicitly before rebuilding');
assert.ok(!fs.existsSync(assets),'Generated media exists; remove it explicitly before rebuilding');
const media=new Map();
for(const item of manifest.media){
 assert.match(item.file,/^media\/[A-Za-z0-9-]+\.(png|webm)$/);
 assert.ok(!media.has(item.file),'Duplicate media');
 const source=path.join(root,item.file);assert.ok(fs.lstatSync(source).isFile());
 const data=fs.readFileSync(source);
 assert.equal(data.length,item.size_bytes);
 assert.equal(crypto.createHash('sha256').update(data).digest('hex'),item.sha256);
 assert.equal(data.subarray(0,item.kind==='screenshot'?8:4).toString('hex'),item.kind==='screenshot'?'89504e470d0a1a0a':'1a45dfa3');
 assert.ok(item.kind==='screenshot'||(item.kind==='video'&&['guided','execution'].includes(item.role)));
 media.set(item.file,{data,url:'/domstride-media/'+runId+'/'+path.basename(item.file)});
}
const generated=[];
const seen=new Set();
for(const page of manifest.pages){
 assert.match(page.id,/^[A-Za-z0-9-]+$/);assert.equal(page.mdx,'mdx/'+page.id+'.mdx');assert.ok(!seen.has(page.id));seen.add(page.id);
 const source=path.join(root,page.mdx);assert.ok(fs.lstatSync(source).isFile());
 let body=fs.readFileSync(source,'utf8').replace(/\r\n/g,'\n');
 assert.ok(body.startsWith('# '));body=body.slice(body.indexOf('\n')+1).trimStart();
 // Adapt presentation only; the portable guide already classifies actions.
 const lines=body.split('\n'),out=[];let active=false,step=0;
 function close(){if(!active)return;if(isFuma&&step)out.push('','</Step>');out.push('','</Steps>','');active=false;}
 for(let line of lines){
  if(line==='### Walkthrough'){close();out.push('## Walkthrough','','<Steps>','');active=true;step=0;continue;}
  if(active&&/^#{1,3} /.test(line))close();
  if(active){
   const match=line.match(/^#### \d+\. (.+)$/);
   if(match){
    if(isFuma){if(step)out.push('','</Step>','');step++;out.push('<Step>','','#### '+match[1],'');}
    else out.push('',(++step)+'. **'+match[1]+'**','');
    continue;
   }
   out.push(isFuma?line:line?'   '+line:'');continue;
  }
  out.push(line);
 }
 close();
 body=out.join('\n').replace(/\]\(([A-Za-z0-9-]+)\.mdx\)/g,(_,id)=>{assert.ok(manifest.pages.some(p=>p.id===id),'Unknown related scenario');return ']('+(isFuma?'/docs':'')+'/generated/'+id.toLowerCase()+'/)';}).replace(/\.\.\/media\/([A-Za-z0-9-]+\.(?:png|webm))/g,(match,name)=>{const entry=media.get('media/'+name);assert.ok(entry,'Unknown media '+name);return entry.url;});
 assert.ok(!body.includes('../media/'));
 // Keep exact source assertions, results and evidence. Only change presentation.
 const frontmatter='---\ntitle: '+JSON.stringify(page.title)+'\ndescription: '+JSON.stringify('Verified historical specification '+page.id)+'\n---\n\n';
 generated.push({name:page.id.toLowerCase()+'.mdx',body:frontmatter+(isFuma?"import { Step, Steps } from 'fumadocs-ui/components/steps';\n\n":"import { Steps } from '@astrojs/starlight/components';\n\n")+body+'\n'});
}
assert.ok(generated.length);
fs.mkdirSync(content,{recursive:true});fs.mkdirSync(assets,{recursive:true});
for(const [file,item] of media)fs.writeFileSync(path.join(assets,path.basename(file)),item.data);
for(const page of generated)fs.writeFileSync(path.join(content,page.name),page.body);
fs.writeFileSync(path.join(site,'generated-publication.json'),JSON.stringify({run_id:runId,pages:generated.map(p=>p.name),media:manifest.media},null,2)+'\n');
console.log('Imported '+generated.length+' '+target+' pages and '+media.size+' verified media assets.');
}
module.exports={importPublication};
