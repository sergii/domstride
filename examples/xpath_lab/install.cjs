// Experimental document-local adapters. Not a general XPath DOM polyfill.
module.exports = function installXPath(win) {
  const doc = win.document;
  if (typeof doc.evaluate === "function") return;
  const candidate = process.env.XPATH_LAB_CANDIDATE || "wgxpath";
  if (candidate === "wgxpath") {
    require("wicked-good-xpath").install({ document: doc });
  } else if (candidate === "xpath") {
    const xpath = require("xpath");
    // Specdrive requests ordered node snapshots only.
    const compile = (expression, resolver) => {
      if (resolver != null) throw new Error("XPATH_LAB_NAMESPACE_RESOLVER_UNSUPPORTED");
      const parsed = xpath.parse(expression);
      return {
        evaluate(context, type) {
          if (type !== 7) throw new Error("XPATH_LAB_RESULT_TYPE_UNSUPPORTED");
          const nodes = parsed.select({ node: context, isHtml: true, allowAnyNamespaceForNoPrefix: true });
          return { snapshotLength: nodes.length, snapshotItem: i => nodes[i] ?? null };
        }
      };
    };
    doc.createExpression = compile;
    doc.evaluate = (expression, context, resolver, type) => compile(expression, resolver).evaluate(context, type);
  } else {
    throw new Error("Unknown XPath lab candidate: " + candidate);
  }
  if (typeof doc.evaluate !== "function" || typeof doc.createExpression !== "function") {
    throw new Error("XPATH_LAB_INSTALL_FAILED");
  }
  if (process.env.XPATH_LAB_TRACE === "1") {
    const evaluate = doc.evaluate;
    const seen = new Set();
    doc.evaluate = function(expression, ...args) {
      const result = evaluate.call(doc, expression, ...args);
      if (!seen.has(expression)) {
        seen.add(expression);
        const nodes = Array.from({ length: result.snapshotLength }, (_, i) => {
          const node = result.snapshotItem(i);
          return { tag: node?.tagName, id: node?.id };
        });
        console.error("XPATH_LAB_QUERY " + JSON.stringify({ candidate, expression, nodes }));
      }
      return result;
    };
  }
};
