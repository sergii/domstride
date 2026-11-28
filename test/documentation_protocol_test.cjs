const assert=require('node:assert/strict');
const {validateDocumentationRun}=require('../lib/domstride/documentation/artifact-validation.cjs');
const spec={format:'domstride.specification',schema_version:1,documents:[{feature:{tags:[{name:'@feature:LIB'}]}}],scenarios:[{scenario_id:'LIB-1',feature_id:'LIB',scenario:{name:'Borrow',steps:[]}}]};
const run={format:'domstride.run',schema_version:1,run_id:'r1',mode:'documentation',status:'passed',cases:[{folder:'case-1',attempt_id:'a1',scenario_id:'LIB-1',status:'passed'}]};
const cases=[{format:'domstride.case',schema_version:1,name:'Borrow',status:'passed',duration_ms:2,feature_id:'LIB',scenario_id:'LIB-1',attempt_id:'a1',folder:'case-1',steps:[{sequence:1,runtime_id:'s1',keyword:'When',text:'Borrow',status:'passed',duration_ms:2}],screenshots:[{file:'screenshots/step-001.png',step_sequence:1,phase:'after'}],videos:[{file:'video-01.webm',label:'Browser',role:'guided',run_id:'r1',attempt_id:'a1'}],evidence_errors:[]}];
validateDocumentationRun(spec,run,cases);
for(const [mutate,message] of [
 [(s,r,c)=>r.schema_version=2,/unsupported format/],
 [(s,r,c)=>r.cases.push({...r.cases[0]}),/duplicate identity/],
 [(s,r,c)=>r.cases[0].folder='../outside',/invalid identifier/],
 [(s,r,c)=>c[0].attempt_id='other',/run entry mismatch/],
 [(s,r,c)=>c[0].feature_id='other',/mismatched specification/],
 [(s,r,c)=>c[0].duration_ms=null,/invalid duration/],
 [(s,r,c)=>c[0].steps[0].sequence=2,/non-contiguous/],
 [(s,r,c)=>c[0].screenshots[0].step_sequence=2,/unknown step/],
 [(s,r,c)=>c[0].screenshots[0].file='../outside.png',/invalid local filename/],
 [(s,r,c)=>c[0].videos[0].run_id='other',/provenance/],
 [(s,r,c)=>c[0].videos[0].role='execution',/mode mismatch/],
 [(s,r,c)=>s.scenarios.push({...s.scenarios[0]}),/duplicate identity/],
 [(s,r,c)=>c.pop(),/count mismatch/]
]){
 const args=structuredClone([spec,run,cases]);mutate(...args);assert.throws(()=>validateDocumentationRun(...args),message);
}
console.log('Documentation protocol validation passed (13 invalid cases).');
