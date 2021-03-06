require! {
  './components/LiveReloadClient.ls'
  './components/PageData.ls'
  './components/RenderGraph.ls'
  './components/Message.ls'
  './components/TabManager.ls'
  './components/Constants.ls'
  './components/ReportManager.ls'
  Promise: bluebird
}

const TAG = "[Background]"

ReportManager.open!

chrome.browser-action.on-clicked.add-listener (tab) ->
  if TabManager.get-state(tab.id) is on
    TabManager.turn-off tab.id
  else
    TabManager.turn-on tab.id

chrome.tabs.on-removed.add-listener (tab-id, remove-info) ->
  TabManager.close tab-id

# ---------------------------------
# PageData & RenderGraph Processing
# ---------------------------------

graph = new RenderGraph window.document.body

chrome.runtime.on-message.add-listener ({type, data}, sender, send-response) ->
  sender-tab-id = sender.tab.id

  switch type
  case \GET_STATE
    # The content script want to know the state of the tab it resides in.
    # Let's send back its state.
    #
    msg = new Message \SET_STATE, TabManager.get-state sender-tab-id
    msg.send sender-tab-id

  case \PAGE_DATA
    console.log TAG, "Page data received", data
    # The content script sends in pageData
    #

    page-data = new PageData data.page

    # Compose edge object upon receiving edge data
    #
    if data.events.length > 0
      edge = new RenderGraph.Edge TabManager.get-renderer(sender-tab-id), data.events

    # Add the page-data and edge to the graph, then update the current renderer of the tab
    #
    TabManager.set-renderer sender-tab-id, graph.add(page-data, edge)


# If the tab state is "on",
# set browser action icon on tab update because it always gets resetted by browser
#
chrome.tabs.on-updated.add-listener (tab-id, change-info) ->
  return unless change-info.status is \loading and TabManager.get-state(tab-id) is on

  # Then change icon to active
  #
  chrome.browser-action.set-icon do
    tab-id: tab-id
    path: Constants.ACTIVE_ICON_PATH


# -----------------------------------------
# LiveReload Connections & Refresh Handling
# -----------------------------------------

var live-reload-client, report-tab-id

(...) <- Object.observe graph.renderers, _, <[add delete]>

renderer-count = graph.renderers.length
console.log TAG, "graph renderer change observed, count: #{renderer-count}"

chrome.browser-action.set-badge-text {text: "" + renderer-count} if renderer-count > 0

if renderer-count > 0 and !live-reload-client
  # When there are renderers in graph,
  # seek for livereload server connection.
  #
  live-reload-client := new LiveReloadClient do
    on-reload: (change) !->
      console.log TAG, "Change detected", change

      ReportManager.start graph.renderers.length

      Promise.map (graph.refresh change.path), (page-diff) ->
        ReportManager.send page-diff
        return page-diff
      .then (results) ->
        console.log TAG, "SeeSS results", results
        ReportManager.end!

    on-connect: !->
      chrome.browser-action.set-badge-background-color color: '#090'
    on-disconnect: !->
      chrome.browser-action.set-badge-background-color color: '#900'


else if renderer-count is 0 and live-reload-client
  # When the render graph becomes empty,
  # we don't need livereload server connection anymore.
  #
  live-reload-client.shut-down!
  live-reload-client := null
