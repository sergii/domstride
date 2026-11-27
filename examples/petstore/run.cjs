const {spawnSync}=require('node:child_process');
const {mkdirSync}=require('node:fs');
const {join,resolve}=require('node:path');
const {existsSync}=require('node:fs');
const {randomUUID,createHash}=require('node:crypto');
const {readFileSync}=require('node:fs');
const mode=process.argv[2]||'fast';
if (!['fast','execution','documentation'].includes(mode)) throw new Error('Expected fast, execution or documentation');
const runId=new Date().toISOString().replace(/[:.]/g,'-')+'-'+randomUUID();
const root=join(__dirname,'artifacts',runId);
mkdirSync(root,{recursive:true});
const start=new Date().toISOString();
const feature=resolve(process.env.PETSTORE_FEATURE||join(__dirname,'../../../petstore/features/marketplace/listings/publish_listing.feature'));
if(!existsSync(feature)) throw new Error('Set PETSTORE_FEATURE to the canonical Petstore feature file');
const sourceSha256=createHash('sha256').update(readFileSync(feature)).digest('hex');
if(!process.env.PETSTORE_BASE_URL)throw new Error('Set PETSTORE_BASE_URL to the isolated local Rails application');
const result=spawnSync(join(__dirname,'node_modules','.bin','cucumber-js'),[
  '--require-module','tsx/cjs','--require','features/support/**/*.ts',
  '--format','progress','--format','message:'+join(root,'messages.ndjson'),
  feature
],{cwd:__dirname,stdio:'inherit',env:{...process.env,RUN_MODE:mode,DOMSTRIDE_ARTIFACTS:root}});
let exportStatus=0;
try {
  require('./generate.cjs').generate(root,{mode,run_id:runId,source_sha256:sourceSha256,recording_profile:mode==='fast'?null:mode==='execution'?'execution':'guided',start,end:new Date().toISOString(),exitCode:result.status,commit:process.env.GIT_COMMIT||process.env.GITHUB_SHA||null,applicationCommit:process.env.PETSTORE_COMMIT||null});
} catch(error) { console.error(error); exportStatus=1; }
console.log('Artifacts: '+root);
process.exitCode=result.error||result.status===null?1:result.status||exportStatus;
