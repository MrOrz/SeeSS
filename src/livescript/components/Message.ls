# All possible messages between background script and content scripts.
#
# Notice that the background script will never tell content script to set
# my-state to 'on' because we want a page-data that is available after reload
# for a "source renderer".
#
const TAG = "[Message]"

class Message
  const TYPES =
    \PAGE_DATA      # [ content -> background ] Sends extracted page data.
    \GET_STATE      # [ content -> background ] Ask current tab state from content script. Expects response.
    \SET_STATE      # [ background -> content ] Tells the content script its state.

  (@type, @data) ->

  # Message sender that returns a promise which resolves to the response data.
  #
  send: (target-tab-id) ->
    console.log TAG, @, target-tab-id

    switch @type

    # content -> background
    case \PAGE_DATA, \GET_STATE
      chrome.runtime.send-message null, {@type, @data}

    # background -> content
    case \SET_STATE
      chrome.tabs.send-message target-tab-id, {@type, @data}

module.exports = Message
