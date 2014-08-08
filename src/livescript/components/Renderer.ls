#
# Renders the given page-data into iframe and keeps track of it.
#

require! {
  Promise: bluebird
}

class Renderer
  (@page-data) ->
    @iframe = document.create-element \iframe
    @iframe.set-attribute \sandbox, 'allow-same-origin allow-scripts'
    @iframe.width = page-data.width
    @iframe.height = page-data.height

    @_promise = _load-page-data @page-data, @iframe .then ~>
      return _take-initial-snapshot @iframe
    .then (snapshot) ~>
      @snapshot = snapshot
      return @ # resolve the current renderer

  #
  # Kick-start the iframe rendering by putting the iframe into a DOM target
  #
  render: (target) ->
    target.insert-before @iframe
    return @_promise

  #
  # Load the page-data into iframe.
  # Returns a promise that is resolved when all data in iframe is loaded.
  #
  function _load-page-data page-data, iframe

    return new Promise (resolve, reject) ->
      iframe.onload = ->
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

        # First, insert load callbacks to page-data DOM to get the exact time when
        # the DOM elements is loaded.

        link-elems = page-data.dom.query-selector-all "link[href][rel=stylesheet]"
        img-elems = page-data.dom.query-selector-all "img[src]"

        unloaded-element-count = link-elems.length + img-elems.length

        # Resolve when all elements are loaded
        if unloaded-element-count > 0
          on-element-load = ->
            this.onload = this.onerror = null # this = the loaded element
            unloaded-element-count -= 1

            resolve! if unloaded-element-count is 0

          for link-elem in link-elems
            link-elem.onload = link-elem.onerror = on-element-load

          for img-elem in img-elems
            img-elem.onload = img-elem.onerror = on-element-load

        # Set document content, which should trigger iframe onload function later
        iframe-document.replace-child page-data.dom.document-element, iframe-document.document-element

        # If no unloaded element at all, resolve immediately.
        resolve! if unloaded-element-count is 0


  function _take-initial-snapshot iframe
    iframe-document = iframe.content-window.document
    walker = iframe-document.create-tree-walker iframe-document.body,
      NodeFilter.SHOW_ELEMENT

    while current-node = walker.next-node!
      console.log \current-node , current-node.node-name

    # Return the snapshot
    return {}

module.exports = Renderer