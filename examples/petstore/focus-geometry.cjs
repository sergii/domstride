// Compute a crop candidate from an observed target, not a timed media cue.
// Keep the output in viewport pixels and preserve the viewport aspect ratio.
function cropForTarget(bounds,viewport,{maxZoom=2.5,padding=0.2}={}){
 const {x,y,width:w,height:h}=bounds,{width:vw,height:vh}=viewport;
 if(![x,y,w,h,vw,vh,maxZoom,padding].every(Number.isFinite)||w<=0||h<=0||vw<=0||vh<=0||maxZoom<1||padding<0)throw Error('Invalid geometry');
 const left=Math.max(0,x),top=Math.max(0,y),right=Math.min(vw,x+w),bottom=Math.min(vh,y+h);
 if(right<=left||bottom<=top)throw Error('Target outside viewport');
 const tw=right-left,th=bottom-top;
 const zoom=Math.max(1,Math.min(maxZoom,vw/(tw*(1+2*padding)),vh/(th*(1+2*padding))));
 const width=vw/zoom,height=vh/zoom;
 const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));
 return {x:clamp((left+right-width)/2,0,vw-width),y:clamp((top+bottom-height)/2,0,vh-height),width,height,zoom};
}
module.exports={cropForTarget};
