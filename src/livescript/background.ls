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