require! {
  rewire
  '../../src/livescript/components/Constants.ls'
  './ChromeMock.ls'.ChromeMock
  './ChromeMock.ls'.ChromeTabsInterface
  './ChromeMock.ls'.ChromeBrowserActionInterface
}

class TabManagerChromeMock implements ChromeTabsInterface, ChromeBrowserActionInterface
chrome-mock = new TabManagerChromeMock

send-spy = sinon.spy!
class MessageMock
  ->
  send: send-spy


var TabManager


(...) <- describe 'TabManager'

# Re-instantiate a brand-new TabManager for each test cases
before-each ->
  TabManager := rewire '../../src/livescript/components/TabManager.ls'
  TabManager.__set__ chrome: chrome-mock, Message: MessageMock, console: log: ->

describe '#turn-on', (...) ->

  it 'turns on multiple tabs', !->
    for i from 1 to 3
      TabManager.turn-on i

    for i from 1 to 3
      expect TabManager.get-state i .to.be on

  it 'refreshes tab when turned on', !->
    const TAB_ID = 321

    spy = chrome-mock.tabs.reload.with-args TAB_ID

    TabManager.turn-on TAB_ID

    expect spy .to.be.called-once!

describe '#turn-off', (...) ->

  it 'turns the correct tab off', !->
    for i from 1 to 3
      TabManager.turn-on i

    TabManager.turn-off 2

    expect TabManager.get-state 1 .to.be on
    expect TabManager.get-state 2 .to.be off
    expect TabManager.get-state 3 .to.be on

  it 'throws when turning non-existance tab off', !->
    expect (-> TabManager.turn-off 123456) .to.throw-error!

  it 'switches browser action icon to inactive', !->
    const TAB_ID = 11

    spy = chrome-mock.browser-action.set-icon.with-args do
      tab-id: TAB_ID
      path: Constants.INACTIVE_ICON_PATH

    TabManager.turn-on TAB_ID
    TabManager.turn-off TAB_ID

    expect spy .to.be.called-once!

  it 'sends message to content script when a tab is turned off', !->
    const TAB_ID = 1234
    spy = send-spy.with-args TAB_ID

    TabManager.turn-on TAB_ID
    TabManager.turn-off TAB_ID

    expect spy .to.be.called-once!


describe '#get-renderer', (...) !->
  it 'gets the correct renderer', !->
    const renderer1 = \renderer1
    const renderer2 = \renderer2

    TabManager.set-renderer 1, renderer1
    TabManager.set-renderer 2, renderer2

    expect TabManager.get-renderer(1) .to.be renderer1
    expect TabManager.get-renderer(2) .to.be renderer2

