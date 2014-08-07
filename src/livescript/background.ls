require! {
  './components/PageData.ls'
}

# rendering-window = null

# chrome.windows.create do
#   focused: false
#   (w) ->
#     rendering-window := w

chrome.runtime.on-message.add-listener (data, sender, send-response) ->
  page-data = new PageData data
  console.log "Received", page-data

  iframe = document.create-element \iframe
  iframe.set-attribute \sandbox, 'allow-same-origin'
  iframe.width = page-data.width
  iframe.height = page-data.height

  # iframe.content-window is only available after it's loaded
  #
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

    # Set document content
    iframe-document.replace-child page-data.dom.document-element, iframe-document.document-element

  # Adding iframe to document triggers loading.
  document.body.insert-before iframe

chrome.browser-action.on-clicked.add-listener (tab) ->
  console.log \Yo!

  chrome.tabs.execute-script tab.id,
    file: "contentScript.bundle.js"
    # (results) -> console.log "execute result: ", results
  #chrome.page-capture.save-as-mHTML tab-id: tab.id, (mhtml-data) ->
  #  object-url = URL.create-object-uRL mhtml-data
  #  console.log "Object-URL:", object-url
  #  chrome.tabs.create do
  #    window-id: rendering-window.id
  #    url: object-url

# chrome.runtime.on-suspend.add-listener ->
#   chrome.windows.remove rendering-window.id if rendering-window.id