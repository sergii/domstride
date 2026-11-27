// Explicit browserless observer policies. No physical geometry or responsive layout.
function installObservers(win, state) {
  const intersections = new Set(), resizes = new Set();
  let deliveries = 0;
  const limit = 64;
  function deliver(callback) {
    if (++deliveries > limit) throw new Error("Observer delivery limit exceeded");
    state.activity += 1;
    callback();
  }
  function assertElement(target) {
    if (!(target instanceof win.Element)) throw new TypeError("Expected Element");
  }
  function logicallyVisible(target) {
    if (!target.isConnected) return false;
    for (let node = target; node; node = node.parentElement) {
      const css = win.getComputedStyle(node);
      if (node.hidden || css.display === "none" || ["hidden","collapse"].includes(css.visibility)) return false;
      if (node.tagName === "DIALOG" && !node.open) return false;
    }
    return true;
  }
  function entry(target, visible) {
    // A logical binary state, not a measured intersection ratio. Reject geometry access.
    const result = { target, isIntersecting: visible, intersectionRatio: visible ? 1 : 0, time: win.performance.now() };
    for (const key of ["boundingClientRect", "intersectionRect", "rootBounds"]) {
      Object.defineProperty(result, key, { get() { throw new Error("UNSUPPORTED_INTERSECTION_GEOMETRY"); } });
    }
    return result;
  }
  win.IntersectionObserver = class {
    #callback;
    #targets = new Map();
    #pending = new Set();
    constructor(callback, options = {}) {
      if (typeof callback !== "function") throw new TypeError("Expected observer callback");
      this.#callback = callback;
      if (options.root != null) assertElement(options.root);
      this.root = options.root ?? null;
      this.rootMargin = options.rootMargin ?? "0px";
      this.thresholds = (Array.isArray(options.threshold) ? options.threshold : [options.threshold ?? 0]).map(Number).sort((a,b)=>a-b);
      if (this.thresholds.some(value => !Number.isFinite(value) || value < 0 || value > 1)) throw new RangeError("Invalid intersection threshold");
      if (options.trackVisibility || options.scrollMargin) throw new Error("UNSUPPORTED_INTERSECTION_OPTIONS");
    }
    observe(target) {
      assertElement(target);
      if (this.#targets.has(target)) return;
      if (this.#targets.size >= 64) throw new Error("Observer target limit exceeded");
      if (!intersections.has(this) && intersections.size >= 64) throw new Error("Observer instance limit exceeded");
      intersections.add(this);
      this.#targets.set(target, null);
      if (state.observerProfile === "logical-visible") {
        this.#pending.add(target);
        win.setTimeout(() => {
          if (!this.#pending.delete(target) || !this.#targets.has(target)) return;
          this.notify(target, logicallyVisible(target) && (!this.root || this.root.contains(target)));
        }, 0);
      }
    }
    unobserve(target) {
      this.#targets.delete(target); this.#pending.delete(target);
      if (!this.#targets.size) intersections.delete(this);
    }
    disconnect() { this.#targets.clear(); this.#pending.clear(); intersections.delete(this); }
    takeRecords() { return []; }
    notify(target, visible) {
      if (!this.#targets.has(target) || this.#targets.get(target) === visible) return false;
      this.#pending.delete(target);
      this.#targets.set(target, visible);
      deliver(() => this.#callback([entry(target, visible)], this));
      return true;
    }
  };
  state.notifyIntersection = (target, visible) => {
    if (typeof visible !== "boolean") throw new TypeError("Expected boolean intersection state");
    return Array.from(intersections).filter(observer => observer.notify(target, visible)).length;
  };
  // Resize is manual only. Never pretend dimensions are measured from the DOM.
  if (state.observerProfile === "manual") {
    win.ResizeObserver = class {
      #callback;
      #targets = new Map();
      constructor(callback) {
        if (typeof callback !== "function") throw new TypeError("Expected observer callback");
        this.#callback = callback;
      }
      observe(target, options = {}) {
        assertElement(target);
        if (options.box && options.box !== "content-box") throw new Error("UNSUPPORTED_RESIZE_BOX");
        if (this.#targets.has(target)) return;
        if (this.#targets.size >= 64 || (!resizes.has(this) && resizes.size >= 64)) throw new Error("Observer target limit exceeded");
        resizes.add(this); this.#targets.set(target, null);
      }
      unobserve(target) { this.#targets.delete(target); if (!this.#targets.size) resizes.delete(this); }
      disconnect() { this.#targets.clear(); resizes.delete(this); }
      notify(target, width, height) {
        if (!this.#targets.has(target)) return false;
        const last = this.#targets.get(target);
        if (last && last.width === width && last.height === height) return false;
        this.#targets.set(target, {width,height});
        const size = Object.freeze({inlineSize:width,blockSize:height});
        const result = {target,contentRect:new win.DOMRectReadOnly(0,0,width,height),contentBoxSize:[size]};
        for (const key of ["borderBoxSize","devicePixelContentBoxSize"]) {
          Object.defineProperty(result,key,{get(){throw new Error("UNSUPPORTED_RESIZE_BOX");}});
        }
        deliver(() => this.#callback([result],this));
        return true;
      }
    };
    state.notifyResize = (target,width,height) => {
      if (![width,height].every(value => typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 100000))
        throw new TypeError("Invalid explicit resize dimensions");
      return Array.from(resizes).filter(observer => observer.notify(target,width,height)).length;
    };
  }
}
module.exports = { installObservers };
