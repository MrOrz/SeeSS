const WINDOW_XPATH = \WINDOW

function queryXPath doc, xpath
  if _fetch-special-xpath doc, xpath
    return that
  else
    doc.evaluate xpath, doc, null, XPathResult.ANY_TYPE, null .iterate-next!

function queryXPathAll doc, xpath
  if _fetch-special-xpath doc, xpath
    return [that]
  else
    iterator = doc.evaluate xpath, doc, null, XPathResult.ANY_TYPE, null

    result = while node = iterator.iterate-next!
      node

    return result

function generateXPath elem

  if elem.node-type is Node.DOCUMENT_NODE
    # End recursion when traversed to owner-document.
    return ''

  else if elem.constructor.name is \Window
    # Special case: if given elem is window
    return WINDOW_XPATH

  new-chunk = if elem.node-name in <[HTML BODY]> or elem.parent-node is null
    "/#{elem.node-name.toLowerCase!}"
  else
    position = Array::index-of.call elem.parent-node.children, elem
    "/*[#{position+1}]"

  return generateXPath(elem.parent-node) + new-chunk

function _fetch-special-xpath (doc, xpath)
  if xpath is ''
    return doc
  else if xpath is WINDOW_XPATH
    return doc.default-view
  else
    return false

module.exports = {queryXPath, queryXPathAll, generateXPath}
