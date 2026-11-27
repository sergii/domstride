// Application-specific documentation rendering and provenance.
const {render}=require('./render-docs.cjs');
const {writeCucumberRun}=require('../../lib/domstride/documentation/cucumber-run-adapter.cjs');
function generate(root,run){
 const {specification:spec,cases}=writeCucumberRun(root,run,{
  producer:'living-documentation-reference',framework:'cucumber-js',runner:'playwright',
  platform:'web',language:'typescript',browser:'chromium',viewport:{width:1280,height:800},videoLabel:'Chromium'
 });
 if(run.mode==='documentation'||run.mode==='execution')render(root,spec.documents,spec,cases,run);
}
module.exports={generate};
