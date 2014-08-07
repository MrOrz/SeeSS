# The use of [\s\S]: matching over multiple lines
# http://stackoverflow.com/questions/1979884/how-to-use-javascript-regex-over-multiple-lines
#
const SCRIPT_ELEM_MATCHER = /<script[^>]*?>[\s\S]*?<\/script>/gim
const LINK_TAG_MATCHER = /<link([^>]*?)>/gim
const HREF_ATTR_MATCHER = /\bhref="([^"]+?)"/i
const STYLE_ELEM_MATCHER = /<style([^>]*?)>([\s\S]*?)<\/style>/gim
const START_TAG_MATCHER = /<([^>]+?)>/
const STYLE_ATTR_MATCHER = /\bstyle="([^"]+?)"/i
const URL_FUNCTION_MATCHER = /url\((['"]?)([^)]+?)\1\)/gim

class PageData

  # Shared parser
  _dom-parser = new DOMParser

  ({html, @url, @width, @height, @scroll-top, doctype}) ->
    @dom = _process-html(html, @url)
    @doctype = _process-doctype doctype

  # Process the links of link[href] and all url()s in <style> or style attributes.
  # Remove the <script> tags.
  #
  function _process-html (html, base-url)
    dom = _dom-parser.parse-from-string html, 'text/html'

    # Remove all script tags
    for script-elem in dom.query-selector-all('script')
      script-elem.remove!

    # Replace link tag href with absolute URLs
    for link-elem in dom.query-selector-all 'link[href]'
      href = link-elem.get-attribute \href
      link-elem.set-attribute \href, (new URL href, base-url .toString!)

    # Replace image/iframe src with absolute URLs
    for img-elem in dom.query-selector-all 'img[src],iframe[src],frame[src]'
      href = img-elem.get-attribute \src
      img-elem.set-attribute \src, (new URL href, base-url .toString!)

    # Replace url() in style tag
    for style-elem in dom.query-selector-all \style
      style-elem.innerHTML = _process-url-function(style-elem.innerHTML, base-url)

    # Replace url() in style attribute of any start tag
    for start-tag in dom.query-selector-all '[style]'
      css = start-tag.get-attribute \style
      start-tag.set-attribute \style, _process-url-function(css, base-url)

    # Return the fully-processed HTML
    return dom

  # Process doctype to a string
  function _process-doctype doctype
    doctype-string = "<!doctype html"
    if doctype.public-id.length
      doctype-string += " public \"#{doctype.public-id}\""
    if doctype.system-id.length
      doctype-string += "\n\"#{doctype.system-id}\""
    doctype-string += ">"

    return doctype-string


  # Process url() in css or style tag
  function _process-url-function (css, base-url)
    return css.replace URL_FUNCTION_MATCHER, (matched-url-func, quote, old-url) ->
      return "url('#{new URL old-url, base-url}')"


module.exports = PageData
