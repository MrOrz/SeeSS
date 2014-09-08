function queryXPath doc, xpath
  doc.evaluate xpath, doc, null, XPathResult.ANY_TYPE, null .iterate-next!

function queryXPathAll doc, xpath
  iterator = doc.evaluate xpath, doc, null, XPathResult.ANY_TYPE, null

  while node = iterator.iterate-next!
    node

function generateXPath elem

  # End recursion when traversed to owner-document.
  if elem.node-type is Node.DOCUMENT_NODE
    return ''

  new-chunk = if elem.node-name in <[HTML BODY]> or elem.parent-node is null
    "/#{elem.node-name.toLowerCase!}"
  else
    position = Array::index-of.call elem.parent-node.children, elem
    "/*[#{position+1}]"

  return generateXPath(elem.parent-node) + new-chunk

module.exports = {queryXPath, queryXPathAll, generateXPath}
