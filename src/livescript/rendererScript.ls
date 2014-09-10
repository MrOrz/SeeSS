require! {
  './components/Constants.ls'
  './components/SerializableEvent.ls'
}

do ->
  is-testing = document.scripts[document.scripts.length-1].has-attribute \unsafe
  return unless window.parent isnt window and
                (is-testing or window.parent.location.origin is "chrome-extension://#{Constants.EXTENSION_ID}")

  extension-matcher = new RegExp "^chrome-extension://#{Constants.EXTENSION_ID}"

  (event) <-! window.add-event-listener \message, _
  return unless is-testing or event.origin.match extension-matcher

  switch event.data.type
  case \EXECUTE
    events = [new SerializableEvent(evt) for evt in event.data.data]

    event-execute-chain = Promise.resolve!

    for evt in events
      event-execute-chain .= then let evt = evt
        evt.dispatch-in-window window

    # Send PAGE_DATA event to parent (background script) after executing all edges
    #
    event-execute-chain.then ->
      window.parent.post-message do
        type: \PAGE_DATA
        data:
          html: document.document-element.outerHTML
          url: location.href
          width: window.inner-width
          height: window.inner-height
          scroll-top: document.body.scroll-top
          doctype:
            public-id: document.doctype?public-id
            system-id: document.doctype?system-id
        \*
