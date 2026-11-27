// Export observed focus intervals only. No subtitles are fabricated for unmatched steps.
const assert=require('node:assert/strict');
function timestamp(ms){
 assert.ok(Number.isFinite(ms)&&ms>=0);
 const n=Math.round(ms),pad=(x,w=2)=>String(x).padStart(w,'0');
 return pad(Math.floor(n/3600000))+':'+pad(Math.floor(n/60000)%60)+':'+pad(Math.floor(n/1000)%60)+'.'+pad(n%1000,3);
}
function focusVtt(cues){
 let last=-1;
 const entries=cues.map(c=>{
  const start=Math.round(c.first_visible_pts_ms),end=Math.round(c.last_visible_pts_ms);
  assert.ok(start>=0&&end>start&&start>last,'Invalid or overlapping observed interval');last=end;
  const label=String(c.label).replace(/[\r\n]+/g,' ').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  return timestamp(start)+' --> '+timestamp(end)+'\nFocus: '+label;
 });
 return 'WEBVTT\n\n'+entries.join('\n\n')+'\n';
}
module.exports={timestamp,focusVtt};
