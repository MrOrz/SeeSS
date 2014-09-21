#
# Renders the given page-data into iframe and keeps track of it.
#

require! {
  Promise: bluebird
  Reloader: '../../../vendor/bower_components/livereload-js/src/reloader.coffee'.Reloader
  Timer: '../../../vendor/bower_components/livereload-js/src/timer.coffee'.Timer
  './PageData.ls'
  './MappingAlgorithm.ls'
  './SerializablePageDiff.ls'
  './IframeUtil.ls'
  './ElementDifference.ls'
  './XPathUtil.ls'.queryXPath
}

class Renderer
  (@page-data) ->
    @iframe = IframeUtil.create-iframe @page-data.width, @page-data.height

    @_promise = load-and-snapshot-page-data @page-data, @iframe
    .then (@snapshot) ~>
      # Register @reloader on the new iframe content window
      @reloader = new Reloader @iframe.content-window, {log: -> , error: ->}, Timer

      # Hack: we don't call @reloader.reload, must provide set its options explicitly.
      @reloader.options = {}

      return @ # resolve the current renderer

  #
  # Kick-start the iframe rendering by putting the iframe into a DOM target
  #
  render: (target) ->
    target.insert-before @iframe, null
    return @_promise

  #
  # Given changed CSS detected by livereload, update the snapshot and returns
  # a promise that resolves to differences between 'before' and 'after' applying the new stylesheets
  #
  applyCSS: (path) ->
    # Invoke reloader to livereload CSS.
    # The style tags may be manipulated here.
    @reloader.reload-stylesheet path

    # Check if all contents loaded
    return IframeUtil.wait-for-assets @iframe.content-window.document
    .then ~>
      # Wait for pseudo element style to be visible in getComputedStyle
      # https://github.com/akoenig/angular-deckgrid/issues/27#issuecomment-38924697
      #
      Promise.delay 100

    .then ~>
      # Take another page snapshot, update @snapshot and return diff
      iframe-document = @iframe.content-window.document
      walker = iframe-document.create-tree-walker iframe-document.body,
        NodeFilter.SHOW_ELEMENT

      idx = 0
      diffs = []
      while current-node = walker.next-node!
        # Calculate new snapshot and the element difference
        new-elem-snapshot = new ElementSnapshot current-node, @iframe.content-window
        element-diff = new-elem-snapshot.diff @snapshot[idx]

        if element-diff
          # Secretly store the diff-id in DOM
          current-node._seess-diff-id = diffs.length
          diffs.push element-diff
        else
          delete current-node._seess-diff-id

        # Update snapshot
        @snapshot[idx] = new-elem-snapshot
        idx += 1

      # Return SerializablePageDiff instance or null
      if diffs.length is 0
        return null
      else
        return new SerializablePageDiff do
          dom: generate-detached-html @iframe
          doctype: @page-data.doctype
          diffs: diffs
          page-data: @page-data

  #
  # Given the source iframe's src, and event sequence,
  # replay the event sequence from source iframe to get to the specific state,
  # and update the snapshot and perform HTML diff algorithm to generate difference.
  #
  # Returns a promise that resolves to an object:
  # page-diff (SerializablePageDiff): The differences of the page.
  # mapping (TreeTreeMap): DOM node mapping.
  #
  applyHTML: (src, edges-promise) ->

    old-iframe = @iframe
    @iframe = IframeUtil.create-iframe @page-data.width, @page-data.height
    iframe-promise = new Promise (resolve, reject) !~>
      @iframe.onload = ~>
        return unless @iframe.src
        @iframe.onload = null
        resolve!

    # Kick start the new iframe loading.
    old-iframe.parent-node.insert-before @iframe, old-iframe
    @iframe.src = src

    process-promise = Promise.all [iframe-promise, edges-promise] .spread (..., edges) ~>

      # Wait for @renderer executes through the edges.
      # The promise resolves to the page sanpshot.
      #
      new Promise (resolve, reject) !~>
        callback = (event) !~>
          return if event.source isnt @iframe.content-window

          switch event.data.type
          case \PAGE_DATA
            window.remove-event-listener \message, callback

            page-data = new PageData event.data.data

            # Remove src attribute, then load page data & take snapshot.
            @iframe.onload = ~>
              @iframe.onload = null
              load-and-snapshot-page-data page-data, @iframe .then resolve

            @iframe.remove-attribute \src

          case \ERROR
            reject "Cannot reach state for reason: #{event.data.data}"

        window.add-event-listener \message, callback

        all-events = []
        for edge in edges
          all-events ++= edge.events

        # Kick start event sequence processing in @iframe
        @iframe.content-window.post-message do
          type: \EXECUTE
          data: all-events
          \*

    .then (new-snapshot) ~>

      # Match the DOM nodes using Valiente's bottom-up algorithm,
      # then map the rest of nodes using diffX, as suggested in discussion section of diffX paper.
      #
      ttmap = MappingAlgorithm.valiente old-iframe.content-window.document.body, @iframe.content-window.document.body
      MappingAlgorithm.diffX old-iframe.content-window.document.body, @iframe.content-window.document.body, ttmap

      # Calculate diff
      #
      diffs = []
      for elem-snapshot in new-snapshot
        matched-old-elem = ttmap.get-node-to elem-snapshot.elem
        unless matched-old-elem
          # No matched old element; the element is new!
          elem-snapshot.elem._seess-diff-id = diffs.length
          diffs.push new ElementDifference elem-snapshot, ElementDifference.TYPE_ADDED

        else
          # Corresponding old element found; calculate element difference
          old-elem-snapshot = @snapshot[matched-old-elem._seess-snapshot-idx]
          elem-diff = elem-snapshot.diff old-elem-snapshot
          if elem-diff
            # Secretly store the diff-id in DOM
            elem-snapshot.elem._seess-diff-id = diffs.length
            diffs.push elem-diff
          else
            delete elem-snapshot.elem._seess-diff-id


          # Mark the referred old element snapshot
          @snapshot[matched-old-elem._seess-snapshot-idx] = \REFERRED

      # Collect all the old element snapshots that is not referred in the previous step.
      #
      # These "unreferred snapshots" are snapshots of the elements that are removed
      # in the new version of html.
      #
      # The diff-id is recorded on the valid parent in the new DOM.
      #
      unreferenced-snapshots = @snapshot.filter (elem-snapshot) -> elem-snapshot isnt \REFERRED
      @snapshot.filter (elem-snapshot) -> elem-snapshot isnt \REFERRED
        .for-each (unreferenced-elem-snapshot) ->
          parent = unreferenced-elem-snapshot.elem.parent-node
          until mapped-parent = ttmap.get-node-from parent
            parent = parent.parent-node

          if mapped-parent._seess-diff-id is undefined
            mapped-parent._seess-diff-id = diffs.length
          else
            mapped-parent._seess-diff-id = "#{mapped-parent._seess-diff-id} #{diffs.length}"

          diffs.push new ElementDifference unreferenced-elem-snapshot, ElementDifference.TYPE_REMOVED, mapped-parent.innerHTML

      # We are done with the old snapshot. Update with new-snapshot now.
      @snapshot = new-snapshot

      # Now we can totally remove the old iframe.
      # There should be no reference to the old iframe after this line.
      old-iframe.remove!

      # Register @reloader on the new iframe content window
      @reloader = new Reloader @iframe.content-window, {log: -> , error: ->}, Timer

      # Hack: we don't call @reloader.reload, must provide set its options explicitly.
      @reloader.options = {}

      # Return SerializablePageDiff instance or null
      if diffs.length is 0
        return {
          page-diff: null
          mapping: ttmap
        }
      else
        return {
          page-diff: new SerializablePageDiff do
            dom: generate-detached-html @iframe
            doctype: @page-data.doctype
            diffs: diffs
            page-data: @page-data
          mapping: ttmap
        }

    return process-promise

  #
  # Load the page-data into iframe.
  # Returns a promise that is resolved when all data in iframe is loaded.
  #
  function load-and-snapshot-page-data page-data, iframe

    return new Promise (resolve, reject) ->
      onload = ->
        # Unset onload callback, because document.close will trigger onload again.
        iframe.onload = null

        IframeUtil.set-document iframe.content-document, page-data.dom, page-data.doctype
        IframeUtil.wait-for-assets iframe.content-document .then resolve

      if !iframe.content-window
        # If the iframe.content-window is not ready yet, wait until it's ready
        iframe.onload = onload
      else
        # Otherwise, just put the new page-data inside the iframe
        onload!

    .then ~>
      # Wait for browsers to render assets.
      # Seems that only setTimeout triggers the re-layout or something like that.
      # requestAnimationFrame often fires before the CSS got applied.
      #
      return Promise.delay 0

    .then ~>
      take-snapshot iframe

  function take-snapshot iframe
    # Take the initial page snapshot by walking the nodes
    #
    iframe-document = iframe.content-window.document
    walker = iframe-document.create-tree-walker iframe-document.body,
      NodeFilter.SHOW_ELEMENT

    idx = 0
    page-snapshot = while current-node = walker.next-node!
      # Secretly put snapshot index reference into DOM
      current-node._seess-snapshot-idx = idx
      idx += 1
      new ElementSnapshot current-node, iframe.content-window

    # Return the snapshot
    return page-snapshot

  # Generate a detatched DOM HTMLElement that marks diff-id on the elements
  # that is changed by CSS or HTML
  #
  # TODO: Not a good encapsulation. This should be done inside SerializableDiff
  # class, even with a static method named "create" could be better than this.
  #
  function generate-detached-html iframe
    iframe-document = iframe.content-window.document

    # Deep-copy the <html> element
    detached = iframe-document.document-element.clone-node true

    # Walk the two DOM trees at the same time.
    # Start walking from body, as we did when generating page snapshots.
    iframe-walker = iframe-document.create-tree-walker iframe-document.body, NodeFilter.SHOW_ELEMENT
    marking-walker = iframe-document.create-tree-walker detached.query-selector(\body), NodeFilter.SHOW_ELEMENT

    # Mark the diff-id as a HTML element attribute to the detached DOM tree.
    #
    do
      if iframe-walker.current-node._seess-diff-id isnt undefined
        marking-walker.current-node.set-attribute SerializablePageDiff.DIFF_ID_ATTR, iframe-walker.current-node._seess-diff-id

    while iframe-walker.next-node! && marking-walker.next-node!

    return detached

#
# Helper class definition for renderer.
#


# Defines what information should be remembered for each element in the page snapshot.
# The page snapshot is an array of ElementSnapshot in DOM tree walk order.
#
class ElementSnapshot

  # Blacklist some computed style properties because their change will reflect
  # in @rect (getBoundingClientRect)
  #
  const COMPUTED_BLACKLIST = <[
    position left top right bottom width height float box-sizing align-self
    margin margin-left margin-right margin-top margin-bottom
  ]>

  (@elem, iframe-window) ->
    # The bounding client rect is relative to viewport, but should still be workable
    @rect = @elem.get-bounding-client-rect!
    @computed = iframe-window.get-computed-style @elem .css-text

    # Set before-elem and after-elem only when the pseudo-element exists.
    #
    # a valid pseudo element should have "content" in computedStyle,
    # at least it should be "''" or "attr(...)".
    #
    # The computed style of non-exist pseudo element will replicate the computed style of parent element,
    # which confuses the diff process, thus should be avoided.
    #
    @before-elem = if (before-style = iframe-window.get-computed-style @elem, \:before).content isnt ''
      before-style.css-text
    else
      ''

    @after-elem = if (after-style = iframe-window.get-computed-style @elem, \:after).content isnt ''
      after-style.css-text
    else
      ''

  diff: (old-elem-snapshot) ->
    is-empty = true

    # Calculate bounding box (left, right, top, bottom)
    differences =
      bounding-box:
        left: @rect.left <? old-elem-snapshot.rect.left
        right: @rect.right >? old-elem-snapshot.rect.right
        top: @rect.top <? old-elem-snapshot.rect.top
        bottom: @rect.bottom >? old-elem-snapshot.rect.bottom

    # Check rect
    for own key, new-value of @rect
      old-value = old-elem-snapshot.rect[key]

      if old-value isnt new-value
        is-empty = false
        differences.rect ?= {}
        differences.rect[key] =
          before: old-value
          after: new-value

    # Check computed, before-elem, after-elem
    for attr-name in <[computed beforeElem afterElem]>
      new-css-text = @[attr-name]
      old-css-text = old-elem-snapshot[attr-name]

      # 1st check: string comparison
      continue if new-css-text is old-css-text

      # 2nd check: compare each css declaration

      # First we should restore css-text to CSS declarations
      #
      existing-properties = {}
      [new-css, old-css] = for css-text in [new-css-text, old-css-text]

        # Collecte CSS declarations (css property - css value map)
        declarations = {}

        for declaration in css-text.split \; .slice 0, -1
          colon-pos = declaration.index-of \:
          property = declaration.slice 0, colon-pos .trim!

          declarations[property] = declaration.slice colon-pos+2
          existing-properties[property] = yes

        # populate either new-css or old-css with the declaration object
        declarations

      # Delete the properties in blacklist, but don't do so for pseudo elements.
      # This is because we can't collect pseudo element dimensions using getBoundingClientRect.
      #
      if attr-name is \computed
        for blacklisted-property in COMPUTED_BLACKLIST
          delete existing-properties[blacklisted-property]

      # Then we compare the new declarations with the old declarations
      #
      for own property of existing-properties when new-css[property] isnt old-css[property]
        is-empty = false
        differences[attr-name] ?= {}
        differences[attr-name][property] =
          before: old-css[property]
          after: new-css[property]

    if is-empty
      return null
    else
      return new ElementDifference differences


# Exports Renderer and ElementDifference
module.exports = Renderer
