require! {
  './components/Constants.ls'
  './components/SerializableEvent.ls'
}

do !->
  # Check if the rendererScript is inside an iframe of a chrome extension,
  # in order to save some calculation for normal frames & iframes.
  #
  # Notice that the checking is rather loose and can be exploited by malicious
  # websites. However, with limited access to the parent DOM
  # (due to same-origin policy) we cannot do much.
  #
  is-testing = document.scripts[document.scripts.length-1]?has-attribute \unsafe
  return unless window.parent isnt window and
                (is-testing or window.parent.chrome.runtime)

  # <style> that disables transitions and animations
  var disable-duration-style-elem

  dom-preprocess-promise = new Promise (resolve, reject) ->
    window.add-event-listener \load, resolve
  .then function disable-duration
    selectors = []

    for stylesheet in document.style-sheets
      for rule in stylesheet.css-rules when rule.type is CSSRule.STYLE_RULE
        if rule.style.transition-duration isnt '' or rule.style.webkit-animation-duration isnt ''
          selectors.push rule.selector-text

    disable-duration-style-elem := document.create-element \style
    disable-duration-style-elem.innerHTML = "#{selectors.join(',')}{transition-duration: 0; -webkit-animation-duration: 0;}"

    document.body.insert-before disable-duration-style-elem, null


  extension-matcher = new RegExp "^chrome-extension://#{Constants.EXTENSION_ID}"
  (event) <-! window.add-event-listener \message, _

  # Strict matching of event origin, preventing malicious websites from stealing
  # our user's data.
  #
  return unless is-testing or event.origin.match extension-matcher

  switch event.data.type
  case \EXECUTE
    events = [new SerializableEvent(evt) for evt in event.data.data]

    event-execute-chain = dom-preprocess-promise

    for let evt in events
      event-execute-chain .= then ->
        evt.dispatch-in-window window

    # Send PAGE_DATA event to parent (background script) after executing all edges
    #
    event-execute-chain.then ->
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
