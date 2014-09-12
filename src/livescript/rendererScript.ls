require! {
  './components/Constants.ls'
  './components/SerializableEvent.ls'
}

do !->
  # Check if the rendererScript is inside an iframe of SeeSS chrome extension,
  # in order to save some calculation for normal frames & iframes.
  #
  is-testing = document.scripts[document.scripts.length-1]?has-attribute \unsafe
  return unless window.parent isnt window and
                (is-testing or window.parent.chrome.runtime.id is Constants.EXTENSION_ID)

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


  (event) <-! window.add-event-listener \message, _

  switch event.data.type
  case \EXECUTE
    events = [new SerializableEvent(evt) for evt in event.data.data]

    event-execute-chain = dom-preprocess-promise

    for let evt in events
      <- event-execute-chain .= then
      evt.dispatch-in-window window

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
