#
# Renders the given page-data into iframe and keeps track of it.
#

require! {
  Promise: bluebird
  Reloader: '../../../vendor/bower_components/livereload-js/src/reloader.coffee'.Reloader
  Timer: '../../../vendor/bower_components/livereload-js/src/timer.coffee'.Timer
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
    target.insert-before @iframe
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
      # Take another page snapshot and return diff
      return _update-snapshot @iframe, @snapshot

  #
  # Given the new DOM, update the snapshot and perform HMTL diff algorithm
  # to generate difference
  #
  applyHTML: (new-dom) ->
    ...

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

  # Updates page snapshot and return the differences
  function _update-snapshot iframe, page-snapshot
    iframe-document = iframe.content-window.document
    walker = iframe-document.create-tree-walker iframe-document.body,
      NodeFilter.SHOW_ELEMENT

    idx = 0
    differences = []
    while current-node = walker.next-node!
      # Calculate new snapshot and the element difference
      new-elem-snapshot = new ElementSnapshot current-node, iframe.content-window
      element-diff = new-elem-snapshot.diff page-snapshot[idx]
      if element-diff
        differences ++= element-diff

      # Update snapshot
      page-snapshot[idx] = new-elem-snapshot
      idx += 1

    return differences

  # Generate new iframe using dimensions specified in page-data object
  #
  function _generate-iframe page-data
    iframe = document.create-element \iframe
    iframe.set-attribute \sandbox, 'allow-same-origin allow-scripts'
    iframe.width = page-data.width
    iframe.height = page-data.height

    return iframe

# Difference between old element and new element
#
# The structure of ElementDifference object is the same as ElementSnapshot instances,
# except that each property value is replaced by {before: <val-before>, after: <val-after>}
#
class ElementDifference
  ( @elem, diff ) ->
    @ <<< diff

#
# Helper class definition for renderer.
#
# Defines what information should be remembered for each element in the page snapshot.
# The page snapshot is an array of ElementSnapshot in DOM tree walk order.
#
class ElementSnapshot
  (@elem, iframe-window) ->
    # The bounding client rect is relative to viewport, but should still be workable
    @rect = elem.get-bounding-client-rect!
    @computed = iframe-window.get-computed-style elem
    @before-elem = iframe-window.get-computed-style elem, \:before
    @after-elem = iframe-window.get-computed-style elem, \:after

  diff: (old-elem-snapshot) ->
    differences = {}
    is-empty = true
    # console.log '[SNAPSHOT DIFF]', @, old-elem-snapshot
    for own attr-name, attributes of @ when attr-name != \elem
      old-snapshot-attr = old-elem-snapshot[attr-name]
      for own key, value of attributes
        old-snapshot-value = old-snapshot-attr[key]

        unless old-snapshot-value == value
          is-empty = false
          differences[attr-name] ?= {}
          differences[attr-name][key] =
            before: old-snapshot-value
            after: value


    if is-empty
      return null
    else
      return new ElementDifference @elem, differences

module.exports = Renderer