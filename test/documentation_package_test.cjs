// Packaging regression fixture: deliberately minimal synthetic artifacts, not real video evidence.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict'),{execFileSync}=require('node:child_process');
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'domstride-docs-test-'));
const root=path.join(temp,'guided'),execution=path.join(temp,'execution');
const save=(dir,file,obj)=>{fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,file),JSON.stringify(obj));};
const run={format:'domstride.run',schema_version:1,status:'passed',source_sha256:'synthetic',applicationCommit:'app',commit:'engine',platform:'web',browser:'chromium',viewport:{width:1280,height:800},end:'2026-11-28',cases:[{folder:'case-one',attempt_id:'attempt-guided'}]};
const feature={name:'Library',description:'Overview:\\nBorrow a book.',tags:[{name:'@feature:LIB-001'}],children:[]};
const scenario={name:'Borrow a book',description:'Synthetic example',steps:[],examples:[]};
const spec={format:'domstride.specification',schema_version:1,documents:[{feature}],scenarios:[{feature_id:'LIB-001',scenario_id:'LIB-001-01',scenario}]};
const record={status:'passed',scenario_id:'LIB-001-01',attempt_id:'attempt-guided',duration_ms:1,steps:[],screenshots:[],evidence_errors:[],videos:[{file:'video-01.webm',role:'guided',run_id:'guided',attempt_id:'attempt-guided'}]};
try{
 save(root,'run.json',{...run,run_id:'guided',mode:'documentation'});
 save(root,'specification.json',spec);
 save(path.join(root,'case-one'),'case.json',record);
 save(execution,'run.json',{...run,run_id:'execution',mode:'execution',cases:[{folder:'case-one',attempt_id:'attempt-execution'}]});
 save(path.join(execution,'case-one'),'case.json',{...record,attempt_id:'attempt-execution',videos:[{file:'video-01.webm',role:'execution',run_id:'execution',attempt_id:'attempt-execution'}]});
 save(root,'video-pair.json',{scenario_id:'LIB-001-01',run_id:'execution',attempt_id:'attempt-execution',guided_run_id:'guided',guided_attempt_id:'attempt-guided'});
 for(const dir of [root,execution])fs.writeFileSync(path.join(dir,'case-one','video-01.webm'),Buffer.from('1a45dfa3','hex'));
 const cli=process.argv[2];
 assert.ok(cli,'Provide domstride executable');
 assert.throws(()=>execFileSync(cli,['docs','export',root],{stdio:'pipe'}));
 execFileSync(cli,['docs','export','--synthetic-reference',root],{stdio:'pipe',cwd:temp});
 const output=path.join(root,'static-export');
 const manifest=JSON.parse(fs.readFileSync(path.join(output,'manifest.json'),'utf8'));
 assert.equal(manifest.pages.length,1);assert.equal(manifest.media.length,2);
 assert.match(fs.readFileSync(path.join(output,'markdown','LIB-001-01.md'),'utf8'),/Borrow a book/);
 assert.throws(()=>execFileSync(cli,['docs','export','--synthetic-reference',root],{stdio:'pipe'}));
 console.log('Verified packaged documentation export for independent synthetic domain, explicit approval and no overwrite.');
}finally{fs.rmSync(temp,{recursive:true,force:true});}
