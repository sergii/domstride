// Logical DOM state only. No rendering, hit testing, modal inertness or layout geometry.
function installVisibility(win) {
  if (typeof win.Element.prototype.checkVisibility === "function") return;
  Object.defineProperty(win.Element.prototype, "checkVisibility", {
    configurable: true, writable: true,
    value: function(options = {}) {
      if (!this.isConnected) return false;
      if (options.contentVisibilityAuto) throw new Error("UNSUPPORTED_CONTENT_VISIBILITY_AUTO");
      const target = win.getComputedStyle(this);
      if (target.display === "contents") return false;
      if ((options.visibilityProperty || options.checkVisibilityCSS) && ["hidden", "collapse"].includes(target.visibility)) return false;
      for (let node = this; node; node = node.parentElement) {
        const style = win.getComputedStyle(node);
        if (style.display === "none" || node.hasAttribute("hidden")) return false;
        if (node !== this && style.contentVisibility === "hidden") return false;
        if ((options.opacityProperty || options.checkOpacity) && style.opacity !== "" && Number(style.opacity) === 0) return false;
      }
      return true;
    }
  });
}

function installDialogs(win) {
  const prototype = win.HTMLDialogElement?.prototype;
  if (!prototype) throw new Error("UNSUPPORTED_DIALOG_ELEMENT");
  const names = ["show", "showModal", "close"];
  if (names.every(name => typeof prototype[name] === "function")) return;
  if (names.some(name => typeof prototype[name] === "function")) throw new Error("UNSUPPORTED_PARTIAL_DIALOG_IMPLEMENTATION");
  const modals = new WeakSet();
  if (!("returnValue" in prototype)) {
    const values = new WeakMap();
    Object.defineProperty(prototype, "returnValue", {
      configurable: true, get() { return values.get(this) ?? ""; },
      set(value) { values.set(this, String(value)); }
    });
  }
  function open(dialog, modal) {
    if (dialog.open) {
      if (modals.has(dialog) !== modal) throw new win.DOMException("Dialog is already open in another mode", "InvalidStateError");
      return;
    }
    if (modal && !dialog.isConnected) throw new win.DOMException("Dialog is not connected", "InvalidStateError");
    dialog.open = true;
    if (modal) modals.add(dialog); else modals.delete(dialog);
  }
  Object.defineProperties(prototype, {
    show: { configurable: true, writable: true, value() { open(this, false); } },
    showModal: { configurable: true, writable: true, value() { open(this, true); } },
    close: { configurable: true, writable: true, value(returnValue) {
      if (!this.open) return;
      if (arguments.length && returnValue !== undefined) this.returnValue = returnValue;
      this.open = false;
      modals.delete(this);
      win.setTimeout(() => this.dispatchEvent(new win.Event("close")), 0);
    } }
  });
}

// jsdom's Window scroll methods are unimplemented. Model requested offsets,
// without claiming actual scroll range, layout, animation or intersection.
function installScroll(win) {
  let x = 0, y = 0, pending = false;
  const number = value => {
    const converted = Number(value);
    return Number.isFinite(converted) ? converted : 0;
  };
  function move(relative, first, second) {
    const options = first !== null && typeof first === "object" ? first : { left: first, top: second };
    if (options.behavior && !["auto", "instant", "smooth"].includes(options.behavior)) throw new TypeError("Invalid scroll behavior");
    if (options.behavior === "smooth") throw new Error("UNSUPPORTED_SMOOTH_SCROLL");
    const nextX = Math.max(0, options.left === undefined ? x : (relative ? x : 0) + number(options.left));
    const nextY = Math.max(0, options.top === undefined ? y : (relative ? y : 0) + number(options.top));
    if (nextX === x && nextY === y) return;
    x = nextX; y = nextY;
    if (!pending) {
      pending = true;
      win.setTimeout(() => {
        pending = false;
        win.document.dispatchEvent(new win.Event("scroll", { bubbles: true }));
      }, 0);
    }
  }
  Object.defineProperties(win, {
    scrollX: { configurable: true, get: () => x },
    pageXOffset: { configurable: true, get: () => x },
    scrollY: { configurable: true, get: () => y },
    pageYOffset: { configurable: true, get: () => y }
  });
  win.scroll = win.scrollTo = (first, second) => move(false, first, second);
  win.scrollBy = (first, second) => move(true, first, second);
}

// Scroll intent is observable, not a fabricated physical position.
function installScrollIntent(win, state) {
  let latest = null;
  state.logicalScroll = () => latest;
  if (typeof win.Element.prototype.scrollIntoView === "function") return;
  Object.defineProperty(win.Element.prototype, "scrollIntoView", {
    configurable: true, writable: true,
    value(options = {}) {
      if (!this.isConnected) return;
      if (typeof options === "boolean") options = { block: options ? "start" : "end" };
      const block = options.block ?? "start", inline = options.inline ?? "nearest", behavior = options.behavior ?? "auto";
      if (![block, inline].every(value => ["start","center","end","nearest"].includes(value))) throw new TypeError("Invalid scroll alignment");
      if (!["auto","instant","smooth"].includes(behavior)) throw new TypeError("Invalid scroll behavior");
      if (behavior === "smooth") throw new Error("UNSUPPORTED_SMOOTH_SCROLL");
      const path = [];
      for (let node = this; node.parentElement; node = node.parentElement)
        path.unshift(Array.prototype.indexOf.call(node.parentElement.children, node));
      latest = { target_path: path, block, inline, behavior };
    }
  });
}

function installLogicalDOM(win, state) {
  installVisibility(win);
  installDialogs(win);
  installScroll(win);
  installScrollIntent(win, state);
}
module.exports = { installLogicalDOM };
