require! {
  './XPathUtil.ls'.queryXPath
  './XPathUtil.ls'.generateXPath
}

# Given an event object (or specify wait timeout),
# produces an serializable event with element property values are replaced with
# the XPath of the element.
#
class SerializableEvent

  # Create a serializable event object, given an DOM event,
  # or a serailzable event object just deserialized from JSON,
  # or a timestamp from the last event.
  #
  (timestamp-or-event) ->
    if typeof timestamp-or-event is \number
      # timestamp-or-event is a timestamp
      @_setup-wait-event timestamp-or-event

    else
      # timestamp-or-event is an event
      @_constructor-name = timestamp-or-event._constructor-name || timestamp-or-event.constructor.name

      if is-dom-event timestamp-or-event
        @_setup-dom-event timestamp-or-event

      else
        @_recover-from-json timestamp-or-event

  # Returns a promise resolved when event is triggered
  #
  dispatch-in-window: (win) ->
    if @type is \WAIT
      return @_dispatch-wait-event-in-window win
    else
      return @_dispatch-dom-event-in-window win

  _dispatch-dom-event-in-window: (win) ->
    return new Promise (resolve, reject) ~>
      target-elem = win.document `query-x-path` @target

      if !target-elem
        reject "Event target '#{@target}' not found"
        return

      target-elem.add-event-listener @type, resolve

      # Input element value changes before "input" event dispatches
      if @type is \input
        target-elem.value = @_input-value

      # Make sure event properties are identical to serialiableEvent.
      #
      # Specific values (such as .which in KeyboardEvent) cannot be set via
      # the constructor of the event.
      #
      # References:
      # http://stackoverflow.com/questions/10455626/keydown-simulation-in-chrome-fires-normally-but-not-the-correct-key
      # https://gist.github.com/termi/4654819
      # http://jsbin.com/pubos/3/edit
      evt = new win[@_constructor-name] @type, @
      for own key, value of @ when key not in <[_constructorName _inputValue target]> and evt[key] isnt value
        try
          delete evt[key]
          Object.define-property evt, key, writable: true, value: value
        catch e
          # Some properties are read-only

      target-elem.dispatch-event evt


  _dispatch-wait-event-in-window: (win) ->
    ...

  _setup-wait-event: (timestamp) !->
    @type = \WAIT
    @timeout = Date.now! - timestamp

  _setup-dom-event: (evt) !->
    target = evt.target

    if target.node-type is Node.DOCUMENT_NODE
      event-window = target.default-view
    else if target.constructor.name is \Window
      event-window = target
    else
      event-window = target.owner-document.default-view

    for property, value of evt when is-relevant(property, value, event-window)
      @[property] = value

    @target = generate-x-path target
    if evt.type is \input
      @_input-value = target.value

  _recover-from-json: (evt) !->
    @ <<< evt

  get-input-value: ->
    @_input-value

  function is-dom-event (evt)
    !evt._constructor-name

  function is-relevant prop, value, event-window
    # Irrelevant event properties:
    #
    # view: a window object, but not necessarily the window object where the event is triggered
    # path: not sure what it is, just a NodeList
    #
    not (typeof value is \function || value instanceof event-window.Element ||
         value is event-window || value is event-window.document ||
         value is undefined || prop in <[view path]> )

module.exports = SerializableEvent
