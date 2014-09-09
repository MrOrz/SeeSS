require! {
  './components/Message.ls'
  './components/SerializableEvent.ls'
}

const MUTATION_DEBOUNCE_PERIOD = 500ms
const EVENTS_OF_INTEREST = <[blur change click mouseover mouseleave scroll]>

# The state of current tab
#
# Notice that the background script will never tell content script to set
# my-state to 'on' because we want a page-data that is available after reload
# for a "source renderer".
#
var my-state

# Mutation observer instance, only populated when my-state is on for the tab.
#
var mutation-observer, debounce-timeout-handle

# Records the user interaction event
#
var last-event

function record-event(evt)
  last-event := new SerializableEvent evt, window


# Register message listeners from background script
#
chrome.runtime.on-message.add-listener ({type, data}, sender, send-response) ->
  switch type
  case \SET_STATE
    my-state := data
    if my-state is on
      # Immedately extract page data and send back to background script
      send-page-data!

      # Instantiate the mutation observer and start observing
      mutation-observer := new MutationObserver (records) ->

        clear-timeout debounce-timeout-handle
        debounce-timeout-handle := set-timeout send-page-data, MUTATION_DEBOUNCE_PERIOD

      mutation-observer.observe document.body, {+subtree, +child-list, +attributes}

      # Capture the event recorders on document body at capturing phase
      #
      for evt in EVENTS_OF_INTEREST
        document.body.add-event-listener evt, record-event, true

    else
      mutation-observer.disconnect! if mutation-observer
      for evt in EVENTS_OF_INTEREST
        document.body.remove-event-listener evt, record-event, true


# On startup, fetch tab status.
#
(new Message \GET_STATE).send!

function send-page-data

  msg = new Message \PAGE_DATA,
    page:
      html: document.document-element.outerHTML
      url: location.href
      width: window.inner-width
      height: window.inner-height
      scroll-top: document.body.scroll-top
      doctype:
        public-id: document.doctype.public-id
        system-id: document.doctype.system-id

    event: last-event

  # Record the current timestamp
  last-event := Date.now!

  msg.send!
