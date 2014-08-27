require! {
  '../../src/livescript/components/SerializableEvent.ls'
}

(...) <-! describe \SerializableEvent, _

describe '#constructor', (...) !->
  # Stored mouse event created by browser natively
  #
  var mouse-event

  # The iframe that mouse-event happened in
  #
  iframe = document.create-element \iframe
  var iframe-doc

  before (cb) ->
    # Create an iframe to put #click-target in,
    # then click the #click-target then populate mouse-event.
    #
    iframe.onload = ->
      iframe.onload = null
      iframe-doc := iframe.content-window.document

      iframe-doc.write '<div id="click-target"></div>'
      iframe-doc.close!

      # The manually-built event that we use to trigger mouse event
      #
      evt = new MouseEvent \click, do
        view: window
        bubbles: true
        cancelable: true
        which: 1
        button: 1
        clientX: 2
        clientY: 3

      # Fetch #click-target, add click handler and trigger a real click event.
      #
      click-target = iframe-doc.get-element-by-id \click-target
      click-target.add-event-listener \click, (e) ->
        # Capture the real-world click event.
        #
        mouse-event := e
        cb!

      click-target.dispatch-event evt

    document.body.insert-before iframe

  # Unmark the click target
  #
  after-each ->
    SerializableEvent.unmark iframe-doc

  it 'marks the event target and can unmark', ->
    sevt = new SerializableEvent mouse-event, iframe.content-window

    expect SerializableEvent.unmark(iframe-doc).id .to.be \click-target


  it 'is serializable', ->
    sevt = new SerializableEvent mouse-event, iframe.content-window

    expect JSON.stringify(sevt) .to.be.a \string

  it 'recovers from unserialization', ->
    sevt = new SerializableEvent mouse-event, iframe.content-window

    deserialized = JSON.parse JSON.stringify sevt

    recovered-sevt = new SerializableEvent deserialized

    expect recovered-sevt .to.eql sevt

  it 'accepts timestamp and calculates timeout', ->
    sevt = new SerializableEvent Date.now!

    expect sevt.type .to.be \WAIT
    expect sevt.timeout .to.be 0
