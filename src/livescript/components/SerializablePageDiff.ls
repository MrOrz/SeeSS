#
# An object that collects every detail information needed to re-create
# all differences of the page in another document.
#
# Changed elements are marked with __seess_diff_id__ attribute.
#
class SerializablePageDiff
  # The HTML element property that stores diff-id of an element
  const @DIFF_ID_ATTR = \__seess_diff_id__

  # Shared parser instance
  parser = new DOMParser

  #
  # dom      Detached body element with its decendants argumented by DIFF_ID_ATTR.
  # @html    HTML text of <body> element of "after" state of a page.
  #
  # Either dom or @html should exist.
  #
  # @diffs   an array mapping numerical diff-id to sanitized ElementDifference instances
  # @ordered ordered array of diff-id.
  #
  ({dom, @html, @diffs, @order=[]}) ->
    if !dom and !@html
      throw new Error 'Either "dom" or "html" should be specified.'

    if !@diffs || @diffs.length is 0
      throw new Error 'diffs should contain at least 1 Renderer.ElementDifference instance'

    # Populate @_dom if dom is specified.
    @_dom = dom

    # Populate missing @html property
    @html = @_dom.outerHTML if !@html

  is-ordered: ->
    @order.length > 0

  ordered-diffs: ->
    # Cache the ordered-diffs
    #
    @_ordered-diffs ?= @order.map (diff-id) ~> @diffs[diff-id]
    return @_ordered-diffs

  dom: ->
    @_generate-dom! unless @_dom
    return @_dom

  get-element-by-diff-id: (diff-id) ->
    @_generate-dom! unless @_dom
    return @_dom.query-selector "[#{@@DIFF_ID_ATTR}=\"#{diff-id}\"]"

  # Generate @_dom only when methods that requires @_dom is invoked
  #
  _generate-dom: !->
    @_dom = parser.parse-from-string @html, 'text/html' .body

  # Method called by JSON.stringify(...).
  # Just include the minimum items needed to re-construct the SerializablePageDiff instance.
  #
  toJSON: ->
    {@html, @diffs, @order}

module.exports = SerializablePageDiff