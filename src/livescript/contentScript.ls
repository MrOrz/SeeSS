# Send HTML back to backgound
#
chrome.runtime.send-message null,
  html: document.document-element.outerHTML
  url: location.href
  width: window.inner-width
  height: window.inner-height
  scroll-top: document.body.scroll-top