# Script that is injected into renderer iframes.
# The injection is done by <script> tag rather than normal content script,
# because when dispatching event from content script (isolated world), the event
# handlers in the document window can only receive event.which = event.charCode = 0.
#
# Reference:
#
# http://stackoverflow.com/questions/4158847/is-there-a-way-to-simulate-key-presses-or-a-click-with-javascript#comment9021733_4176116
#

require! {
  './components/SerializableEvent.ls'
}

# <style> that disables transitions and animations
var disable-duration-style-elem

dom-preprocess-promise = new Promise (resolve, reject) ->
  window.add-event-listener \load, resolve
.then ->
  # Disable transitions using <style>
  selectors = []
  collect-selectors-with-duration = (stylesheet) ->
    for rule in stylesheet.css-rules when rule.type is CSSRule.STYLE_RULE
      if rule.style.transition-duration isnt '' or rule.style.webkit-animation-duration isnt ''
        selectors.push rule.selector-text

  xhr-promises = []

  for stylesheet in document.style-sheets
    if stylesheet.css-rules
      collect-selectors-with-duration stylesheet
    else
      # CSS from external origin. Try fetching it using cross-origin CORS.
      xhr-promises.push new Promise (resolve, reject) !->
        url = new URL(stylesheet.href, location.href)
        xhr = new XMLHttpRequest
        xhr.onreadystatechange = ->
          return if xhr.ready-state isnt 4

          if xhr.status is 200
            doc = (new DOMParser).parse-from-string("<style>#{xhr.response-text}</style>", 'text/html')
            collect-selectors-with-duration doc.query-selector(\style).sheet
            resolve!
          else
            # Cannot get CORS CSS, just give up and resolve immediately.
            resolve!

        xhr.open \GET, url
        xhr.send!

  return Promise.all xhr-promises .then ->
    # selectors[] is fully populated. Insert <style> now.
    #
    disable-duration-style-elem := document.create-element \style
    disable-duration-style-elem.innerHTML = "#{selectors.join(',')}{transition-duration: 0; -webkit-animation-duration: 0;}"
    document.body.insert-before disable-duration-style-elem, null
.then defer-animation-frame

function defer-animation-frame
  # Just in case event callbacks uses requestAnimationFrame.
  # In seessMock requestAnimationFrame is mocked using setTimeout with
  # its timeout <= 16ms.
  #
  return new Promise (resolve, reject) ->
    set-timeout resolve, 16

(event) <-! window.add-event-listener \message, _

switch event.data.type
case \EXECUTE
  events = [new SerializableEvent(evt) for evt in event.data.data]

  event-execute-chain = dom-preprocess-promise

  for let evt in events
    event-execute-chain .= then ->
      evt.dispatch-in-window window
    .then defer-animation-frame

  # Send PAGE_DATA event to parent (background script) after executing all edges
  #
  event-execute-chain.then !->
    # All events are executed, this <style> is no longer needed.
    # Remove it so that it does not interfere with xdiff process.
    disable-duration-style-elem.remove!

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

  .catch (reason) !->
    # Post-message cannot serialize Error instances
    reason = reason.message if reason instanceof Error

    window.parent.post-message do
      type: \ERROR
      data: reason
      \*
