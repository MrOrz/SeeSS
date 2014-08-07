#
# Renders the given page-data into iframe and keeps track of it.
#

require! {
  Promise: bluebird
}

class Renderer
  (@page-data) ->
    @iframe = document.create-element \iframe
    @iframe.set-attribute \sandbox, 'allow-same-origin'
    @iframe.width = page-data.width
    @iframe.height = page-data.height

    # Setup load promise
    @_promise = new Promise (resolve, reject) ~>

      # @iframe.content-window is only available after it's loaded
      #
      @iframe.onload = ~>
        # Unset onload callback, because document.close will trigger onload again.
        @iframe.onload = null

        iframe-document = @iframe.content-window.document

        # Set document doctype.
        # Since neither iframe-document.insert-before nor replace-child changes the document.compatMode,
        # document.write may be the only way to leave browser's quirks mode.
        #
        iframe-document.open!
        iframe-document.write page-data.doctype
        iframe-document.close!

        # Set document content
        iframe-document.replace-child page-data.dom.document-element, iframe-document.document-element
        resolve @

  #
  # Kick-start the iframe rendering by putting the iframe into a DOM target
  #
  render: (target) ->
    target.insert-before @iframe
    return @_promise

module.exports = Renderer