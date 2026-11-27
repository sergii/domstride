// Only for a viewport-only video with verified full-frame mapping and a known video clock.
// For X11 desktop recordings use a calibrated frame-space transform instead.
async function viewportTarget(locator, page, frame) {
  const viewport=page.viewportSize();
  if (!viewport || viewport.width!==frame.width || viewport.height!==frame.height) return null;
  const rect=await locator.boundingBox();
  if (!rect) return null;
  const x=Math.max(0,rect.x),y=Math.max(0,rect.y);
  const right=Math.min(viewport.width,rect.x+rect.width),bottom=Math.min(viewport.height,rect.y+rect.height);
  if (right<=x || bottom<=y) return null;
  return {x:x/viewport.width,y:y/viewport.height,width:(right-x)/viewport.width,height:(bottom-y)/viewport.height};
}
module.exports={viewportTarget};
