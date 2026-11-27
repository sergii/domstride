// Explicit static environment, not a CSS layout or responsive rendering engine.
const WIDTH = 1200, HEIGHT = 1000;
function installStaticMedia(win) {
  if (typeof win.matchMedia === "function") throw new Error("Static media profile would override a native implementation");
  const evaluate = query => {
    const text = query.trim().toLowerCase();
    if (text === "all" || text === "screen") return true;
    if (text === "print") return false;
    let match = text.match(/^\(\s*(min-|max-)?(width|height)\s*:\s*(\d+(?:\.\d+)?)px\s*\)$/);
    if (match) {
      const value = match[2] === "width" ? WIDTH : HEIGHT;
      const limit = Number(match[3]);
      return match[1] === "min-" ? value >= limit : match[1] === "max-" ? value <= limit : value === limit;
    }
    match = text.match(/^\(\s*prefers-reduced-motion\s*:\s*(reduce|no-preference)\s*\)$/);
    if (match) return match[1] === "reduce";
    match = text.match(/^\(\s*prefers-color-scheme\s*:\s*(light|dark)\s*\)$/);
    if (match) return match[1] === "light";
    match = text.match(/^\(\s*orientation\s*:\s*(portrait|landscape)\s*\)$/);
    if (match) return match[1] === "landscape";
    throw new Error("UNSUPPORTED_MEDIA_QUERY: " + query);
  };
  win.matchMedia = query => {
    const media = String(query);
    const matches = evaluate(media);
    const result = new win.EventTarget();
    Object.defineProperties(result, {
      media: { value: media, enumerable: true },
      matches: { value: matches, enumerable: true }
    });
    result.onchange = null;
    result.addListener = listener => result.addEventListener("change", listener);
    result.removeListener = listener => result.removeEventListener("change", listener);
    return result;
  };
}
module.exports = { installStaticMedia };
