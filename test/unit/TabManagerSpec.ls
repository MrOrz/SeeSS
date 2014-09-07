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
  before-each ->
    for i from 1 to 10
      TabManager.turn-on i

  it 'turns the correct tab off', !->
    TabManager.turn-off 2

    expect TabManager.get-state 1 .to.be on
    expect TabManager.get-state 2 .to.be off

  it 'throws when turning non-existance tab off', !->
    expect (-> TabManager.turn-off 123456) .to.throw-error!

  it 'switches browser action icon to inactive', !->
    spy = chrome-mock.browser-action.set-icon.with-args do
      tab-id: 3
      path: Constants.INACTIVE_ICON_PATH

    TabManager.turn-off 3

    expect spy .to.be.called-once!

  it 'sends message to content script when a tab is turned off', !->
    spy = send-spy.with-args 4

    TabManager.turn-off 4

    expect spy .to.be.called-once!


describe '#get-renderer', (...) !->
  it 'gets the correct renderer', !->
    const renderer1 = \renderer1
    const renderer2 = \renderer2

    TabManager.set-renderer 1, renderer1
    TabManager.set-renderer 2, renderer2

    expect TabManager.get-renderer(1) .to.be renderer1
    expect TabManager.get-renderer(2) .to.be renderer2

