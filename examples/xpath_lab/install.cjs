const wgxpath = require("wicked-good-xpath");

// Install on the actual document, not the Window's exported Document prototype.
module.exports = function installXPath(win) {
  const doc = win.document;
  if (typeof doc.evaluate === "function") return;
  const target = { document: doc };
  wgxpath.install(target);
  if (typeof doc.evaluate !== "function" || typeof doc.createExpression !== "function") {
    throw new Error("XPATH_LAB_INSTALL_FAILED");
  }
};
