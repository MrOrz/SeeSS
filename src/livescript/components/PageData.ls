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

  # Process url() in css or style tag
  _process-url-function = (css, base-url) ->
    return css.replace URL_FUNCTION_MATCHER, (matched-url-func, quote, old-url) ->
      return "url('#{new URL old-url, base-url}')"


  # Process the links of link[href] and all url()s in <style> or style attributes.
  # Remove the <script> tags.
  #
  _process-html = (html, base-url) ->
    # Remove all script tags
    return html.replace SCRIPT_ELEM_MATCHER, ''

    # Replace link tag href with absolute URLs
    .replace LINK_TAG_MATCHER, (matched-link-tag, attributes) ->
      new-attributes = attributes.replace HREF_ATTR_MATCHER, (matched, href) ->
        new-href = new URL href, base-url .toString!
        return "href=\"#{new-href}\""
      return "<link#{new-attributes}>"

    # Replace url() in style tag
    .replace STYLE_ELEM_MATCHER, (matched-style-elem, style-attrs, style-content) ->
      return "<style#{style-attrs}>#{ _process-url-function(style-content, base-url) }</style>"

    # Replace url() in style attribute of any start tag
    .replace START_TAG_MATCHER, (matched-start-tag, start-tag) ->
      new-start-tag = start-tag.replace STYLE_ATTR_MATCHER, (matched, style-content) ->
        return "style=\"#{ _process-url-function(style-content, base-url) }\""
      return "<#{new-start-tag}>"


  ({html, @url, @width, @height, @scroll-top}) ->
    @html = _process-html(html, @url)

module.exports = PageData
