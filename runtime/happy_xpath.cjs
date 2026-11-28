// Experimental XPath 1.0 node-set queries on the live Happy DOM tree.
// Loaded only for Happy DOM XPath queries; native XPath and CSS stay unchanged.
const xpath = require("xpath");

function select(expression, root) {
  const nodes = xpath.parse(expression).select({
    node: root,
    isHtml: true,
    allowAnyNamespaceForNoPrefix: true
  });
  // Capybara handles are element nodes, not scalar or attribute results.
  if (nodes.some(node => node.nodeType !== 1)) throw new Error("UNSUPPORTED_XPATH_RESULT");
  return nodes;
}

module.exports = { select };
