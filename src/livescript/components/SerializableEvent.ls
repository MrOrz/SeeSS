# Given an event object (or specify wait timeout),
# produces an serializable event and mark the event target on DOM.
#
# The event target mark can be unmarked using unmark() static method,
# which returns the marked event target.
#
#

class SerializableEvent

  const @MARK = \__SEESS_EVENT_TARGET__

  # Retrieve and unmark the event target element
  #
  @unmark = (marked-doc) ->
    target = marked-doc.query-selector "[#{@@MARK}]"
    target.remove-attribute @@MARK if target

    return target

  # Create a serializable event object, given an DOM event,
  # or a serailzable event object just deserialized from JSON,
  # or a timestamp from the last event.
  #
  (timestamp-or-event, event-window) ->
    if typeof timestamp-or-event is \number
      @type = \WAIT
      @timeout = Date.now! - timestamp-or-event
    else
      # "timestamp-or-event" may be a DOM event or a serializable event instance
      # recovered from JSON
      #
      evt = timestamp-or-event
      is-dom-event = !evt.constructor-name

      if is-dom-event
        # Copy non-DOM element properties over.
        # Here we also skip properties that cannot be stringified,
        # like those whose value is a function or is undefined.
        #
        for property, value of evt when !(value instanceof event-window.Element || typeof value is \function || value is undefined)
          @[property] = value

        # Delete other loop causing elements
        delete @view # a window object, but not necessarily the window object where the event is triggered
        delete @path # not sure what it is, just a NodeList

        # Mark the target on document if a DOM event element is given
        #
        evt.target.set-attribute @@MARK, ''

      else
        # If is deserialized data, prototype inheritance is enough
        @ <<< evt

      # Records the constructor name (Event object constructor)
      #
      @constructor-name = evt.constructor-name || evt.constructor.name


module.exports = SerializableEvent
