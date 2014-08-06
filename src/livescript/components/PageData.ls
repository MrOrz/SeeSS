# http://stackoverflow.com/questions/1979884/how-to-use-javascript-regex-over-multiple-lines
const SCRIPT_ELEM_MATCHER = /<script[^>]*>[\s\S]*?<\/script>/gim
const LINK_TAG_MATCHER = /<link([^>]*)>/gim
const HREF_ATTR_MATCHER = /\bhref="(.+?)"\b/i

class PageData

  # Process the links of link[href] and all url()s in <style> or style attributes.
  # Remove the <script> tags.
  #
  _process-html = (html, base-url) ->
    # Remove all script tags
    return html.replace SCRIPT_ELEM_MATCHER, ''

    # Replace link tag href with absolute URLs
    .replace LINK_TAG_MATCHER, (matched, attributes) ->
      return attributes.replace HREF_ATTR_MATCHER, (matched, href) ->
        new-href = new URL href, base-url .toString!
        return "href=\"#{new-href}\""


  ({html, @url, @width, @height, @scroll-top}) ->
    @html = _process-html(html, @url)

module.exports = PageData
