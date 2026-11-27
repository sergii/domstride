// Compatibility entrypoint for the synthetic Petstore reference.
const assert=require('node:assert/strict');
const core=require('../../lib/domstride/documentation/export-docs.cjs');
const exportDocs=root=>core.exportDocs(root,{syntheticReference:true});
if(require.main===module){
 assert.equal(process.argv[2],'--synthetic-reference');
 assert.equal(process.argv.length,4);
 exportDocs(process.argv[3]);
}
module.exports={exportDocs};
