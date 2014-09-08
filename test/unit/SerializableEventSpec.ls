require! {
  '../../src/livescript/components/SerializableEvent.ls'
  '../../src/livescript/components/XPathUtil.ls'.queryXPath
}

(...) <-! describe \SerializableEvent, _

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

    iframe-doc.write '<div id="click-target">SerializableEvent click target</div>'
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

    listener = (e) ->
      # Capture the real-world click event.
      #
      click-target.remove-event-listener \click, listener
      mouse-event := e
      cb!

    click-target.add-event-listener \click, listener

    click-target.dispatch-event evt

  document.body.insert-before iframe, null


describe '#constructor', (...) !->

  it 'is serializable', ->
    sevt = new SerializableEvent mouse-event, iframe.content-window

    expect JSON.stringify(sevt) .to.be.a \string

  it 'recovers from unserialization', ->
    sevt = new SerializableEvent mouse-event, iframe.content-window

    deserialized = JSON.parse JSON.stringify sevt

    recovered-sevt = new SerializableEvent deserialized

    expect recovered-sevt .to.eql sevt

  it 'converts event target to correct XPath', ->
    sevt = new SerializableEvent mouse-event, iframe.content-window
    recovered-sevt = new SerializableEvent JSON.parse JSON.stringify sevt
    recovered-target = iframe.content-window.document `query-x-path` recovered-sevt.target

    expect recovered-target .to.be mouse-event.target

  it 'accepts timestamp and calculates timeout', ->
    sevt = new SerializableEvent Date.now!

    expect sevt.type .to.be \WAIT
    expect sevt.timeout .to.be 0

describe '#dispatch-in-window', (...) !->

  it 'dispatches DOM events', ->

    sevt = new SerializableEvent mouse-event, iframe.content-window
    spy = sinon.spy!

    target = iframe-doc.get-element-by-id \click-target

    target.add-event-listener \click, spy

    sevt.dispatch-in-window iframe.content-window .then ->
      expect spy .to.be.called-once!

  it 'dispatches wait events'

  it 'rejects when event target not found', ->
    sevt = new SerializableEvent mouse-event, iframe.content-window

    resolve-spy = sinon.spy!
    reject-spy = sinon.spy!

    # Assume the event target is updated to something not exist
    sevt.target = '/NOT_EXIST'

    sevt.dispatch-in-window iframe.content-window
    .then resolve-spy, reject-spy
    .finally !->
      expect resolve-spy .to.be.not-called!
      expect reject-spy .to.be.called-once!

