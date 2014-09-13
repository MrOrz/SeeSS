require! {
  '../../src/livescript/components/SerializableEvent.ls'
  '../../src/livescript/components/XPathUtil.ls'.queryXPath
}

(...) <-! describe \SerializableEvent, _

# Stored mouse event created by browser natively
#
var mouse-event, input-event

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
    iframe-doc := iframe.content-document

    iframe-doc.write '<div id="click-target">SerializableEvent click target</div><input type="text" id="input-target" value="test">'
    iframe-doc.close!

    # The manually-built event that we use to trigger mouse event
    #
    manual-click-event = new MouseEvent \click, do
      bubbles: true
      cancelable: true
      which: 1
      button: 1
      clientX: 2
      clientY: 3

    manual-input-event = new Event \input, do
      bubbles: true
      cancelable: true

    # Fetch #click-target, add click handler and trigger a real click event.
    #
    click-target = iframe-doc.get-element-by-id \click-target
    input-target = iframe-doc.get-element-by-id \input-target

    # Capture the real-world events.
    #
    click-listener = (e) ->
      click-target.remove-event-listener \click, click-listener
      mouse-event := e

    input-listener = (e) ->
      input-target.remove-event-listener \input, input-listener
      input-event := e
      cb!

    click-target.add-event-listener \click, click-listener
    input-target.add-event-listener \input, input-listener

    click-target.dispatch-event manual-click-event
    input-target.dispatch-event manual-input-event

  document.body.insert-before iframe, null


describe '#constructor', (...) !->

  it 'is serializable', ->
    sevt = new SerializableEvent mouse-event

    expect JSON.stringify(sevt) .to.be.a \string

  it 'recovers from unserialization', ->
    sevt = new SerializableEvent mouse-event

    deserialized = JSON.parse JSON.stringify sevt

    recovered-sevt = new SerializableEvent deserialized

    expect recovered-sevt .to.eql sevt

  it 'converts event target to correct XPath', ->
    sevt = new SerializableEvent mouse-event
    recovered-sevt = new SerializableEvent JSON.parse JSON.stringify sevt
    recovered-target = iframe.content-window.document `query-x-path` recovered-sevt.target

    expect recovered-target .to.be mouse-event.target

  it 'accepts timestamp and calculates timeout', ->
    sevt = new SerializableEvent Date.now!

    expect sevt.type .to.be \WAIT
    expect sevt.timeout .to.be.less-than 5ms # 5ms should be long enough


  it 'can serialize events dispatched to document element', (cb) ->
    document-event-handler = (evt) ->
      iframe-doc.remove-event-listener \click, document-event-handler
      sevt = new SerializableEvent evt

      expect JSON.stringify(sevt) .to.be.a \string

      cb!

    iframe-doc.add-event-listener \click, document-event-handler
    iframe-doc.dispatch-event mouse-event

  it 'serializes events dispatched to window', (cb) ->
    window-event-handler = (evt) ->
      iframe.content-window.remove-event-listener \click, window-event-handler
      sevt = new SerializableEvent evt

      expect JSON.stringify(sevt) .to.be.a \string

      cb!

    iframe.content-window.add-event-listener \click, window-event-handler
    iframe.content-window.dispatch-event mouse-event

describe '#dispatch-in-window', (...) !->

  it 'dispatches DOM events', ->

    sevt = new SerializableEvent mouse-event
    spy = sinon.spy!

    target = iframe-doc.get-element-by-id \click-target

    target.add-event-listener \click, spy

    sevt.dispatch-in-window iframe.content-window .then ->
      expect spy .to.be.called-once!

  it 'dispatches wait events'

  it 'rejects when event target not found', ->
    sevt = new SerializableEvent mouse-event

    resolve-spy = sinon.spy!
    reject-spy = sinon.spy!

    # Assume the event target is updated to something not exist
    sevt.target = '/NOT_EXIST'

    sevt.dispatch-in-window iframe.content-window
    .then resolve-spy, reject-spy
    .then !->
      expect resolve-spy .to.be.not-called!
      expect reject-spy .to.be.called-once!

  it 'serializes and dispatches input events along with input content', ->
    input-target = iframe.content-document.get-element-by-id \input-target

    sevt = new SerializableEvent input-event

    # Unset the input-target's value
    input-target.value = ''

    sevt.dispatch-in-window iframe.content-window
    .then !->
      expect input-target.value .to.be \test
