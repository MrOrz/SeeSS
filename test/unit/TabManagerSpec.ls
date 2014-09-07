require! {
  rewire
  './ChromeMock.ls'.ChromeMock
  './ChromeMock.ls'.ChromeTabsInterface
  './ChromeMock.ls'.ChromeBrowserActionInterface
}

class TabManagerChromeMock implements ChromeTabsInterface, ChromeBrowserActionInterface

chromeMock = new TabManagerChromeMock

TabManager = rewire '../../src/livescript/components/TabManager.ls'
TabManager.__set__ chrome: chromeMock, console: log: ->

(...) <- describe 'TabManager'

describe '#turn-on', (...) ->

  it 'turns on multiple tabs', !->
    for i from 1 to 3
      TabManager.turn-on i

    for i from 1 to 3
      expect TabManager.get-state i .to.be on

  it 'refreshes tab when turned on', !->
    spy = chromeMock.tabs.reload.with-args 321

    TabManager.turn-on 321

    expect spy .to.be.called-once!

