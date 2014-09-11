module.exports =
  # Generate new iframe using dimensions specified in width & height
  #
  create-iframe: (width, height) ->
    iframe = document.create-element \iframe
    iframe.set-attribute \sandbox, 'allow-same-origin allow-scripts'
    iframe.width = width
    iframe.height = height

    return iframe

  # Returns a promise that resolves when all assets are loaded
  #
  wait-for-assets: (doc) ->
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
