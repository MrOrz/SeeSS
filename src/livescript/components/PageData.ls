# http://stackoverflow.com/questions/1979884/how-to-use-javascript-regex-over-multiple-lines
const SCRIPT_ELEM_MATCHER = /<script[^>]*>[\s\S]*?<\/script>/gim
const LINK_TAG_MATCHER = /<link([^>]*)>/gim
const HREF_ATTR_MATCHER = /\bhref="([^"]+)"/i

class PageData

  # Process the links of link[href] and all url()s in <style> or style attributes.
  # Remove the <script> tags.
  #
  _process-html = (html, base-url) ->
    # Remove all script tags
    return html.replace SCRIPT_ELEM_MATCHER, ''

    # Replace link tag href with absolute URLs
    .replace LINK_TAG_MATCHER, (matched, attributes) ->
      new-attributes = attributes.replace HREF_ATTR_MATCHER, (matched, href) ->
        new-href = new URL href, base-url .toString!
        return "href=\"#{new-href}\""
      return "<link#{new-attributes}>"


  ({html, @url, @width, @height, @scroll-top}) ->
    @html = _process-html(html, @url)

module.exports = PageData
