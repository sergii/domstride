// Limited DOM form interactions, not physical keyboard or browser file picker emulation.
const MAX_UPLOAD = 8 * 1024 * 1024;
const event = (win, node, name) => node.dispatchEvent(new win.Event(name, { bubbles: true }));

function selectOption(win, node, selected) {
  if (node.tagName !== "OPTION") throw new Error("UNSUPPORTED_SELECT_TARGET");
  const select = node.closest("select");
  if (!select || select.disabled || node.disabled || node.closest("optgroup")?.disabled || select.matches(":disabled")) throw new Error("Element is disabled");
  if (!selected && !select.multiple) throw new Error("UNSUPPORTED_UNSELECT_SINGLE");
  if (node.selected !== selected) {
    node.selected = selected;
    event(win, select, "input");
    event(win, select, "change");
  }
  return true;
}

// Implicit submission is restricted to ordinary single-line form controls.
function submitOnEnter(node) {
  if (node.tagName !== "INPUT" || !node.form) return;
  const form = node.form;
  const submitter = Array.from(form.elements).find(el =>
    (el.tagName === "BUTTON" && el.type === "submit") ||
    (el.tagName === "INPUT" && ["submit", "image"].includes(el.type)));
  if (submitter) {
    if (!submitter.matches(":disabled")) submitter.click();
    return;
  }
  const blocking = Array.from(form.elements).filter(el => el.tagName === "INPUT" &&
    ["text","search","url","tel","email","password","date","month","week","time","datetime-local","number"].includes(el.type));
  if (blocking.length <= 1) form.requestSubmit();
}

function sendKeys(win, node, keys, implicitSubmit = false) {
  const text = node.tagName === "TEXTAREA" || (node.tagName === "INPUT" && ["text", "search", "tel", "url", "password"].includes(node.type));
  if (!text) throw new Error("UNSUPPORTED_KEY_TARGET");
  if (node.matches(":disabled") || node.readOnly) throw new Error("Element is disabled or readonly");
  const special = new Set(["Backspace", "Delete", "ArrowLeft", "ArrowRight", "Home", "End", "Enter", "Escape", "Tab"]);
  if (keys.some(key => key.kind !== "text" && !(key.kind === "special" && special.has(key.value)))) throw new Error("UNSUPPORTED_KEY");
  node.focus();
  for (const item of keys) {
    for (const key of item.kind === "text" ? Array.from(item.value) : [item.value]) {
      const down = new win.KeyboardEvent("keydown", { key, bubbles: true, cancelable: true });
      if (node.dispatchEvent(down)) {
        let start = node.selectionStart ?? node.value.length, end = node.selectionEnd ?? start;
        let insert = item.kind === "text" ? key : null;
        if (key === "Enter" && item.kind === "special" && node.tagName === "TEXTAREA") insert = "\n";
        else if (key === "Enter" && item.kind === "special" && implicitSubmit) submitOnEnter(node);
        if (item.kind === "special" && key === "Backspace") {
          if (start === end) start = Math.max(0, start - (Array.from(node.value.slice(0, start)).pop()?.length || 0));
          insert = "";
        }
        if (item.kind === "special" && key === "Delete") {
          if (start === end) end += Array.from(node.value.slice(end))[0]?.length || 0;
          insert = "";
        }
        if (insert !== null) {
          const value = node.value.slice(0, start) + insert + node.value.slice(end);
          if (value !== node.value) {
            node.value = value;
            node.setSelectionRange(start + insert.length, start + insert.length);
            event(win, node, "input");
          }
        } else if (["ArrowLeft", "ArrowRight", "Home", "End"].includes(key)) {
          const pos = key === "Home" ? 0 : key === "End" ? node.value.length :
            key === "ArrowLeft" ? Math.max(0, start - 1) : Math.min(node.value.length, end + 1);
          node.setSelectionRange(pos, pos);
        }
      }
      node.dispatchEvent(new win.KeyboardEvent("keyup", { key, bubbles: true }));
    }
  }
  return true;
}

function sendPageKeys(win, keys) {
  const node = win.document.activeElement;
  if (!node) throw new Error("UNSUPPORTED_KEY_TARGET");
  if (node.tagName === "TEXTAREA" || (node.tagName === "INPUT" && ["text","search","tel","url","password"].includes(node.type))) {
    return sendKeys(win, node, keys, true);
  }
  // Non-editable targets receive only explicitly supported named events.
  if (keys.some(key => key.kind !== "special" || !["Enter","Escape","ArrowLeft","ArrowRight"].includes(key.value))) throw new Error("UNSUPPORTED_KEY_TARGET");
  for (const { value: key } of keys) {
    const down = new win.KeyboardEvent("keydown", { key, bubbles: true, cancelable: true });
    if (node.dispatchEvent(down) && key === "Enter" && node.matches("button, a[href], input[type=submit]") && !node.matches(":disabled")) node.click();
    node.dispatchEvent(new win.KeyboardEvent("keyup", { key, bubbles: true }));
  }
  return true;
}

const attached = new WeakMap();
function attachFiles(win, node, entries) {
  if (node.tagName !== "INPUT" || node.type !== "file") throw new Error("UNSUPPORTED_FILE_TARGET");
  if (node.matches(":disabled")) throw new Error("Element is disabled");
  if (!node.multiple && entries.length > 1) throw new Error("Multiple files require a multiple input");
  const buffers = entries.map(entry => Buffer.from(entry.data, "base64"));
  if (buffers.reduce((sum, buffer) => sum + buffer.length, 0) > MAX_UPLOAD) throw new Error("Upload byte limit exceeded");
  const files = entries.map((entry, index) => new win.File([new Uint8Array(buffers[index])], entry.name, {type: entry.type}));
  // jsdom does not expose a writable native FileList. Keep the limitation explicit.
  Object.defineProperty(files, "item", {value: i => files[i] || null});
  Object.freeze(files);
  Object.defineProperty(node, "files", {configurable: true, get: () => files});
  attached.set(node, files);
  event(win, node, "input");
  event(win, node, "change");
  return true;
}

function installFormData(win) {
  const Native = win.FormData;
  if (!Native) return;
  win.FormData = class extends Native {
    constructor(form, submitter) {
      if (form === undefined) super();
      else if (submitter === undefined) super(form);
      else super(form, submitter);
      if (!form) return;
      const fields = Array.from(form.elements || []);
      const names = new Set(fields.filter(node => attached.has(node) && node.name && !node.matches(":disabled")).map(node => node.name));
      for (const name of names) {
        const matching = fields.filter(node => node.name === name && !node.matches(":disabled"));
        if (matching.some(node => node.type !== "file" || !attached.has(node))) throw new Error("UNSUPPORTED_SHARED_FILE_FIELD_NAME");
        this.delete(name);
        for (const node of matching) for (const file of attached.get(node)) this.append(name, file, file.name);
      }
    }
  };
}

async function nodeFormData(win, form) {
  const output = new FormData();
  let size = 0;
  for (const [name, value] of form.entries()) {
    if (typeof value === "string") {
      size += Buffer.byteLength(value);
      output.append(name, value);
    } else {
      size += value.size;
      if (size > MAX_UPLOAD) throw new Error("Upload byte limit exceeded");
      const bytes = await new Promise((resolve, reject) => {
        const reader = new win.FileReader();
        reader.onload = () => resolve(reader.result);
        reader.onerror = () => reject(reader.error || new Error("File read failed"));
        reader.readAsArrayBuffer(value);
      });
      output.append(name, new Blob([bytes], {type: value.type}), value.name || "blob");
    }
    if (size > MAX_UPLOAD) throw new Error("Upload byte limit exceeded");
  }
  return output;
}

module.exports = { selectOption, sendKeys, sendPageKeys, attachFiles, installFormData, nodeFormData, MAX_UPLOAD };
