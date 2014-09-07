# A singleton class that keeps track of all tabs' state machines
#
require! {
  './Constants.ls'
  './Message.ls'
}

const TAG = "[TabManager]"

TabManager = do ->
  # Map tab-id to TabStateMachine instance
  #
  state-machines = {}

  # Map tab-id to renderer instance.
  # Maintaining this relationship helps creating edges between renderers.
  #
  current-renderers = {}

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

    # Maintain current-renderer map
    #
    set-renderer: (tab-id, renderer) ->
      current-renderers[tab-id] = renderer

    get-renderer: (tab-id) ->
      current-renderers[tab-id]


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
      path: Constants.INACTIVE_ICON_PATH

  function turn-on tab-id
    # Reload the turned-on tab.
    # The icon is setted on tab update.
    #
    chrome.tabs.reload tab-id, {-bypassCache}

module.exports = TabManager