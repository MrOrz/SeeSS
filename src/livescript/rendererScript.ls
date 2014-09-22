# Inject injectedRendererScript using script tags.
# This script is a content script injected to all frames in order to
# do cross-domain communication with its parent Renderer instance.
#

require! {
  './components/Constants.ls'
}

# Check if the rendererScript is inside an iframe of SeeSS chrome extension,
# in order to save some calculation for normal frames & iframes.
#
is-testing = document.scripts[document.scripts.length-1]?has-attribute \unsafe
if window.parent isnt window and
  (is-testing or window.parent.chrome.runtime.id is Constants.EXTENSION_ID)

  script-tag = document.create-element \script
  if is-testing
    script-tag.src = "http://localhost:9876/base/src/livescript/injectedRendererScript.ls"
  else
    script-tag.src = "chrome-extension://#{Constants.EXTENSION_ID}/injectedRendererScript.js"

  # Neither do <head> nor <body> is available now.
  # Directly insert into <html> instead.
  #
  document.document-element.append-child script-tag

