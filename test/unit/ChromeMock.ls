class ChromeMock
  mock: yes

class Listener
  add-listener: (@handler) ->

  # Assume there is only one handler for the event
  trigger: -> @handler ...


ChromeTabsInterface =
  tabs: {}

ChromeTabsInterface.tabs `add-methods` <[get getCurrent connect sendRequest sendMessage getSelected getAllInWindow create duplicate query highlight update move reload remove detectLanguage captureVisibleTab executeScript insertCSS setZoom getZoom setZoomSettings getZoomSettings]>
ChromeTabsInterface.tabs `add-events ` <[Created Updated Moved SelectionChanged ActiveChanged Activated HighlightChanged Highlighted Detached Attached Removed Replaced ZoomChange]>


ChromeBrowserActionInterface =
  browser-action: {}

ChromeBrowserActionInterface.browser-action `add-methods` <[setTitle getTitle setIcon setPopup getPopup setBadgeText getBadgeText setBadgeBackgroundColor getBadgeBackgroundColor enable disable]>
ChromeBrowserActionInterface.browser-action `add-events` <[Clicked]>


module.exports = {ChromeMock, ChromeTabsInterface, ChromeBrowserActionInterface}

#
# Helpers
#

function add-methods obj, methods
  for method in methods
    obj[method] = sinon.spy!

function add-events obj, events
  for evt in events
    obj["on#{evt}"] = new Listener
