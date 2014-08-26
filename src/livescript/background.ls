require! {
  './components/LiveReloadClient.ls'
  './components/PageData.ls'
  './components/RenderGraph.ls'
  './components/Message.ls'
}

const TAG = "[Background]"

# --------------------
# Tab State Processing
# --------------------

class TabStateMachine
  (@tab-id) ->
    console.log TAG, "Tab #{@tab-id} statemachine instantiated"
    @state = off

  set: (new-state) ->
    # Ignore same-state transition
    return if new-state is @state
    old-state = @state

    # Perform state transition
    @state = new-state

    console.log TAG, "Tab #{@tab-id} state #{old-state} -> #{new-state}"

    # State transition actions
    switch old-state
    case on
      switch new-state
      | off => turn-off @tab-id
      | _ => ...
    case off
      switch new-state
      | on => turn-on @tab-id
      | _ => ...
    default then ...


  # Transition functions
  #
  function turn-off tab-id
    (new Message \SET_STATE, \off).send tab-id

    chrome.browser-action.set-icon do
      tab-id: tab-id
      path:
        \19 : 'assets/19-inactive.png'
        \38 : 'assets/19-inactive@2x.png'

  function turn-on tab-id
    # Reload the turned-on tab.
    # The icon is setted on tab update.
    #
    chrome.tabs.reload tab-id, {-bypassCache}

# A singleton class that keeps track of all tabs' state machine
#
TabManager = do ->
  state-machines = {}

  return do

    # Do cleanup when a tab is closed
    #
    close: (tab-id) ->
      state-machine = state-machines[tab-id]
      return unless state-machine
      # state-machine.set off # No need, because the tab is closing
      delete state-machines[tab-id]

    # Set a tab's state machine to "on" state.
    # If the state machine does not exist yet, generate one.
    #
    turn-on: (tab-id) ->
      state-machine = (state-machines[tab-id] ?= new TabStateMachine(tab-id))
      state-machine.set on

    # Set a tab's state machine to "off" state
    # The state should have instantiated before.
    #
    turn-off: (tab-id) ->
      unless state-machine = state-machines[tab-id]
        ...

      state-machine.set off

    # Get state for a specific tab. Defaults to "off".
    #
    get-state: (tab-id) ->
      if state-machine = state-machines[tab-id]
        return state-machine.state
      else
        return off

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
  switch type
  case \GET_STATE
    # The content script want to know the state of the tab it resides in.
    # Let's send back its state.
    #
    target-tab-id = sender.tab.id
    msg = new Message \SET_STATE, TabManager.get-state target-tab-id
    msg.send target-tab-id

  case \PAGE_DATA
    console.log \TAG, "Page data received", data
    # The content script sends in pageData
    #
    page-data = new PageData data
    graph.add page-data

# If the tab state is "on",
# set browser action icon on tab update because it always gets resetted by browser
#
chrome.tabs.on-updated.add-listener (tab-id, change-info) ->
  return unless change-info.status is \loading and TabManager.get-state(tab-id) is on

  # Then change icon to active
  #
  chrome.browser-action.set-icon do
    tab-id: tab-id
    path:
      \19 : 'assets/19-active.png'
      \38 : 'assets/19-active@2x.png'



# -----------------------------------------
# LiveReload Connections & Refresh Handling
# -----------------------------------------

var live-reload-client

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
      results <- Promise.all graph.refresh(change.path) .then
      console.log TAG, "SeeSS results", results
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
