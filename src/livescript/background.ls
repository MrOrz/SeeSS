require! {
  './components/LiveReloadClient.ls'
  './components/PageData.ls'
  './components/RenderGraph.ls'
}

# rendering-window = null

# chrome.windows.create do
#   focused: false
#   (w) ->
#     rendering-window := w

graph = new RenderGraph window.document.body

chrome.runtime.on-message.add-listener (data, sender, send-response) ->
  page-data = new PageData data
  graph.add page-data

chrome.tabs.on-updated.add-listener (tab-id, change-info, tab) ->
  # console.log \Yo!!, change-info, tab
  return unless change-info.status is \loading and change-info.url and change-info.url.match(/^http:\/\/localhost/)

  chrome.tabs.execute-script tab.id,
    file: "contentScript.bundle.js"
    (results) -> console.log "execute result: ", results


chrome.browser-action.on-clicked.add-listener (tab) ->
  console.log \Yo!, new LiveReloadClient (change) ->
    console.log "Change detected", change
    results <- Promise.all graph.refresh(change.path) .then
    console.log "SeeSS results", results


#   chrome.tabs.execute-script tab.id,
#     file: "contentScript.bundle.js"
  #chrome.page-capture.save-as-mHTML tab-id: tab.id, (mhtml-data) ->
  #  object-url = URL.create-object-uRL mhtml-data
  #  console.log "Object-URL:", object-url
  #  chrome.tabs.create do
  #    window-id: rendering-window.id
  #    url: object-url

# chrome.runtime.on-suspend.add-listener ->
#   chrome.windows.remove rendering-window.id if rendering-window.id