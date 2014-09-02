#
# Renders the given page-data into iframe and keeps track of it.
#

require! {
  Promise: bluebird
  Reloader: '../../../vendor/bower_components/livereload-js/src/reloader.coffee'.Reloader
  Timer: '../../../vendor/bower_components/livereload-js/src/timer.coffee'.Timer
  './DiffXMatcher.ls'
  './SerializablePageDiff.ls'
}

class Renderer
  (@page-data) ->
    @iframe = _generate-iframe @page-data

    @_promise = _load-and-snapshot-page-data @page-data, @iframe
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
    return _register-load-callbacks @iframe.content-window.document
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
      differences = []
      while current-node = walker.next-node!
        # Calculate new snapshot and the element difference
        new-elem-snapshot = new ElementSnapshot current-node, @iframe.content-window
        element-diff = new-elem-snapshot.diff @snapshot[idx]

        if element-diff
          # Secretly store the diff-id in DOM
          current-node._seess-diff-id = differences.length
          differences.push element-diff
        else
          delete current-node._seess-diff-id

        # Update snapshot
        @snapshot[idx] = new-elem-snapshot
        idx += 1

      # Return early if no differences found
      return null if differences.length is 0


      # Produce HTML for SerializablePageDiff
      # ...
      return new SerializablePageDiff do
        diffs: differences

  #
  # Given the new DOM, update the snapshot and perform HTML diff algorithm
  # to generate difference.
  # Returns a promise that resolves to the page differences.
  #
  applyHTML: (new-html) ->

    # Update @page-data with a new instance with the new HTML
    @page-data = new PageData do
      html: new-html
      url: @page-data.url
      width: @page-data.width
      height: @page-data.height
      scroll-top: @page-data.scroll-top
      doctype: @page-data.doctype

    new-iframe = _generate-iframe @page-data

    # Load iframe
    @_promise = _load-and-snapshot-page-data @page-data, new-iframe
    .then (new-snapshot) ~>
      # Register @reloader on the new iframe content window
      @reloader = new Reloader @iframe.content-window, {log: -> , error: ->}, Timer

      # Calculate diff
      matcher = new DiffXMatcher @iframe.content-window.document, new-iframe.content-window.document

      diffs = []
      for elem-snapshot in new-snapshot
        matched-old-elem = matcher.to-old-node elem-snapshot.elem
        unless matched-old-elem
          # No matched old element; the element is new!
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
      # These "unreferred snapshots" are snapshots of the elements that are removed
      # in the new version of html.
      unreferenced-snapshots = @snapshot.filter (elem-snapshot) -> elem-snapshot isnt \REFERRED
      diffs ++= @snapshot.filter (elem-snapshot) -> elem-snapshot isnt \REFERRED
        .map (unreferenced-elem-snapshot) ->
          new ElementDifference unreferenced-elem-snapshot, ElementDifference.TYPE_REMOVED

      # We are done with the old snapshot. Update with new-snapshot now.
      @snapshot = new-snapshot

      # Now we can totally replace the old @iframe with the new one.
      # There should be no reference to the old iframe after this line.
      @iframe = new-iframe

      # Return early if no differences found
      return null if diffs.length is 0

      # Produce HTML for SerializablePageDiff
      # ...

      return new SerializablePageDiff do
        diffs: diffs

    # Kick start the new iframe loading.
    @iframe.parent-node.replace-child new-iframe, @iframe

    return @_promise


  #
  # Helper function that returns a promise that resolves when all assets
  # are loaded
  #
  function _register-load-callbacks doc
    return new Promise (resolve, reject) ->

      # First, check the already loaded elements in the current document
      #
      # CSS file exists in document.styleSheets only after loaded.
      is-loaded = {[stylesheet.href, true] for stylesheet in doc.styleSheets}

      # <img> appears in document.images even when not loaded.
      # The `complete` boolean property seems to be true even when not rendered yet.
      # We can only go for img.naturalWidth or img.naturalHeight
      #
      for img in doc.images when img.naturalWidth
        is-loaded[img.src] = true

      # Secondly, insert load callbacks to page-data DOM to get the exact time when
      # the DOM elements is loaded.

      link-elems = doc.query-selector-all "link[href][rel=stylesheet]"
      img-elems = doc.query-selector-all "img[src]"

      unloaded-element-count = link-elems.length + img-elems.length

      if unloaded-element-count > 0
        # Resolve when all elements are loaded
        on-element-load = ->
          this.onload = this.onerror = null # this = the loaded element
          unloaded-element-count -= 1

          resolve! if unloaded-element-count is 0

        for link-elem in link-elems
          # Usually link-elem.__LiveReload_pendingRemoval implies the link is loaded.
          # However, in test scripts we replace the href so that it is not true.
          #
          if is-loaded[link-elem.href] || link-elem.__LiveReload_pendingRemoval
            # The <link> is already loaded, remove the mis-added element counts
            unloaded-element-count -= 1
          else
            link-elem.onload = link-elem.onerror = on-element-load

        for img-elem in img-elems
          if is-loaded[img-elem.src]
            # The <img> is already loaded, remove the mis-added element counts
            unloaded-element-count -= 1
          else
            img-elem.onload = img-elem.onerror = on-element-load

      # If no unloaded element at all, resolve immediately.
      resolve! if unloaded-element-count is 0

  #
  # Load the page-data into iframe.
  # Returns a promise that is resolved when all data in iframe is loaded.
  #
  function _load-and-snapshot-page-data page-data, iframe

    return new Promise (resolve, reject) ->
      onload = ->
        # Unset onload callback, because document.close will trigger onload again.
        iframe.onload = null

        iframe-document = iframe.content-window.document

        # Set document doctype.
        # Since neither iframe-document.insert-before nor replace-child changes the document.compatMode,
        # document.write may be the only way to leave browser's quirks mode.
        #
        iframe-document.open!
        iframe-document.write page-data.doctype
        iframe-document.close!

        # Set document content, the assets inside iframe document starts to load.
        iframe-document.replace-child page-data.dom.document-element, iframe-document.document-element

        # Register load callback
        _register-load-callbacks iframe-document .then resolve

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


  # Generate new iframe using dimensions specified in page-data object
  #
  function _generate-iframe page-data
    iframe = document.create-element \iframe
    iframe.set-attribute \sandbox, 'allow-same-origin allow-scripts'
    iframe.width = page-data.width
    iframe.height = page-data.height

    return iframe

  # Generate a html string representing
  #

#
# Helper class definition for renderer.
#

# Difference between old element and new element
#
# The structure of ElementDifference object is the same as ElementSnapshot instances,
# except that each property value is replaced by {before: <val-before>, after: <val-after>},
# and has @type attributes in addition.
#
# However, if @type is not TYPE_MOD, the property value will be a scalar term,
# since there is no "before" or "after" when adding or removing elements.
#
class ElementDifference
  @TYPE_MOD = 0
  @TYPE_ADDED = 1
  @TYPE_REMOVED = 2

  ( diff-or-snapshot, @type = @@TYPE_MOD ) ->
    @ <<< diff-or-snapshot

# Defines what information should be remembered for each element in the page snapshot.
# The page snapshot is an array of ElementSnapshot in DOM tree walk order.
#
class ElementSnapshot

  # Blacklist some computed style properties because their change will reflect
  # in @rect (getBoundingClientRect)
  #
  const COMPUTED_BLACKLIST = <[position left top right bottom width height float margin margin-left margin-right margin-top margin-bottom box-sizing]>

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
    differences = {}
    is-empty = true

    # Check rect
    for own key, new-value of @rect
      old-value = old-elem-snapshot.rect[key]

      unless old-value == new-value
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
module.exports.ElementDifference = ElementDifference
