const assert=require('node:assert/strict');
const {contextSections,classifySteps}=require('./documentation-model.cjs');
const context=contextSections('Overview:\nAn example.\n\nActors:\n- Seller\n- Buyer\n\nPreconditions:\n- Signed in.');
assert.equal(context.overview,'An example.');
assert.equal(context.actors,'- Seller\n- Buyer');
assert.equal(context.prerequisites,'- Signed in.');
const steps=['Given','And','When','And','Then','And','When','Then'].map((keyword,i)=>({keyword,source_step_id:String(i),background:i===0}));
assert.deepEqual(classifySteps(steps,new Map()).map(s=>s.guide_phase),['setup','context','action','action','outcome','outcome','action','outcome']);
console.log('Verified description sections and inherited Gherkin phase classification');
