const assert=require('node:assert/strict');
const {cropForTarget}=require('./focus-geometry.cjs');
const viewport={width:1280,height:800};
for(const bounds of [{x:100,y:100,width:300,height:30},{x:0,y:0,width:100,height:40},{x:1100,y:730,width:180,height:70},{x:0,y:0,width:1280,height:800}]){
 const c=cropForTarget(bounds,viewport);
 assert.ok(c.zoom>=1&&c.zoom<=2.5);assert.ok(c.x>=0&&c.y>=0&&c.x+c.width<=1280+1e-8&&c.y+c.height<=800+1e-8);
 assert.ok(c.x<=bounds.x+1e-8&&c.y<=bounds.y+1e-8&&c.x+c.width>=bounds.x+bounds.width-1e-8&&c.y+c.height>=bounds.y+bounds.height-1e-8);
 assert.ok(Math.abs(c.width/c.height-1280/800)<1e-8);
}
assert.throws(()=>cropForTarget({x:1400,y:0,width:50,height:50},viewport));
console.log('Verified crop candidates preserve aspect ratio, target visibility and viewport bounds');
