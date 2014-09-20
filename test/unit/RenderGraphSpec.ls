require! {
  rewire
  '../../src/livescript/components/PageData.ls'
  '../../src/livescript/components/RenderGraph.ls'
  '../../src/livescript/components/SerializableEvent.ls'
  '../../src/livescript/components/XPathUtil.ls'.generate-x-path
}

# A Renderer mock that only stores fake page data, without creating additional iframes
#
class SimpleObjectRendererMock
  (@page-data) ->

  # required by RenderGraph#add
  render: ->

class PageDataMock
  (@html) ->


(...) <-! describe \RendererGraph, _

describe '#add', (...) !->

  var RenderGraph

  before ->
    # We only test if the graph implementation works here. No need for real Renderers,
    # which inserts irrelevant rendering iframes.
    #

    RenderGraph := rewire '../../src/livescript/components/RenderGraph.ls'
    RenderGraph.__set__ Renderer: SimpleObjectRendererMock


  it "creates renderer instance", ->
    graph = new RenderGraph document.body

    renderer0 = graph.add (new PageDataMock \node0)
    renderer1 = graph.add (new PageDataMock \node1), (new RenderGraph.Edge renderer0, \edge-0-1)
    renderer2 = graph.add (new PageDataMock \node2), (new RenderGraph.Edge renderer1, \edge-1-2)

    expect graph.adj-list.0.1.events .to.be \edge-0-1
    expect graph.adj-list.1.0 .to.be undefined
    expect graph.adj-list.1.2.events .to.be \edge-1-2
    expect graph.adj-list.0.2 .to.be undefined

  it "recognizes and reuses duplicated renderer instance", ->
    graph = new RenderGraph document.body

    # Visit order: 0 -> 1 -> 0 -> 2 -> 3 -> 0
    #
    renderer0 = graph.add (new PageDataMock \node0)
    renderer1 = graph.add (new PageDataMock \node1), (new RenderGraph.Edge renderer0, \edge-0-1)
    graph.add (new PageDataMock \node0), (new RenderGraph.Edge renderer1, \edge-1-0)
    renderer2 = graph.add (new PageDataMock \node2), (new RenderGraph.Edge renderer0, \edge-0-2)
    renderer3 = graph.add (new PageDataMock \node3), (new RenderGraph.Edge renderer2, \edge-2-3)
    graph.add (new PageDataMock \node0), (new RenderGraph.Edge renderer3, \edge-3-0)

    # There should be only node 0~3
    expect graph.renderers .to.have.length 4
    expect graph.adj-list.4 .to.be undefined

describe '#children-of', (...) !->

  var RenderGraph

  before ->
    # We only test if the graph implementation works here. No need for real Renderers,
    # which inserts irrelevant rendering iframes.
    #

    RenderGraph := rewire '../../src/livescript/components/RenderGraph.ls'
    RenderGraph.__set__ Renderer: SimpleObjectRendererMock


  it 'returns correct children', ->
    graph = new RenderGraph document.body

    renderer0 = graph.add (new PageDataMock \node0)
    renderer1 = graph.add (new PageDataMock \node1), (new RenderGraph.Edge renderer0, \edge-0-1)
    renderer2 = graph.add (new PageDataMock \node2), (new RenderGraph.Edge renderer1, \edge-1-2)

    child0 = graph.children-of 0

    expect child0.length .to.eql 1
    expect child0.0.in-edge.events .to.be \edge-0-1
    expect child0.0.renderer.page-data.html .to.be \node1

    child1 = graph.children-of 1

    expect child1.length .to.eql 1
    expect child1.0.in-edge.events .to.be \edge-1-2
    expect child1.0.renderer.page-data.html .to.be \node2

    child2 = graph.children-of 2

    expect child2.length .to.eql 0


describe '#refresh', (...) !->
  it 'refreshes all iframe when CSS changed, and outputs difference', ->
    const NEW_CSS = 'renderer-css-color-test2.css'

    graph = new RenderGraph document.body
    renderer1 = graph.add (new PageData html: __html__['test/fixtures/renderer-css-color-test.html'], url: location.href)
    renderer2 = graph.add (new PageData html: __html__['test/fixtures/rendergraph-css-test.html'], url: location.href)

    # After all renderer are loaded, put the CSS to refresh inside all renderers,
    # and start refreshing
    <- Promise.all [renderer1._promise, renderer2._promise] .then
    new-css = load-css renderer1.iframe.content-window.document, NEW_CSS
    load-css renderer2.iframe.content-window.document, NEW_CSS

    results <- Promise.all graph.refresh new-css .then

    # There should be 2 SerializablePageDiff instances
    expect results .to.have.length 2

    for page-diff in results
      # For all SerializablePageDiff instances,
      # there should be only one ElementDifference that reports
      # the color of h1 changed from blue to red.
      #
      expect page-diff.diffs .to.have.length 1
      expect page-diff.query-diff-id(0).node-name .to.be \H1
      expect page-diff.diffs.0.computed.color.before .to.be "rgb(0, 0, 255)"
      expect page-diff.diffs.0.computed.color.after .to.be "rgb(255, 0, 0)"

  it 'refreshes all iframe when HTML changed, and outputs difference', !->
    graph = new RenderGraph document.body
    const filename = "base/test/served/renderer-html-click-test-src-changed.html"

    # Use http://127.0.0.1 instead of http://localhost to simulate cross-origin scenario
    #
    url = "http://127.0.0.1:#{location.port}/#{filename}"

    root = graph.add (new PageData html: __html__['test/fixtures/renderer-html-click-test-src.html'], url: url)

    edge-root-state0 = new RenderGraph.Edge root, [new SerializableEvent({type: \click, _constructor-name: \MouseEvent, target: '/html/body/ul/*[1]'})]
    state0 = graph.add (new PageData html: __html__['test/fixtures/renderer-html-click-test-state0.html'], url: url), edge-root-state0

    edge-state0-state1 = new RenderGraph.Edge state0, [new SerializableEvent({type: \click, _constructor-name: \MouseEvent, target: '/html/body/ul/*[2]'})]
    state1 = graph.add (new PageData html: __html__['test/fixtures/renderer-html-click-test-state1.html'], url: url), edge-state0-state1

    edge-state1-state2 = new RenderGraph.Edge state1, [new SerializableEvent({type: \click, _constructor-name: \MouseEvent, target: '/html/body/ul/*[3]'})]
    state2 = graph.add (new PageData html: __html__['test/fixtures/renderer-html-click-test-state2.html'], url: url), edge-state1-state2

    results <- Promise.all graph.refresh(filename) .then

    expect results .to.have.length 4
    for page-diff, idx in results
      # Number of Color change: root has 2 (ul and li), state0 has 3 (ul and li*2), and vice versa
      expect page-diff.diffs .to.have.length idx + 2

  it 'refreshes when edges contains events targeting document, window, <html> and <body>.', ->
    graph = new RenderGraph document.body
    const filename = "base/test/served/renderer-html-doc-click-test-state0.html"

    # Use http://127.0.0.1 instead of http://localhost to simulate cross-origin scenario
    #
    url = "http://127.0.0.1:#{location.port}/#{filename}"

    root = graph.add (new PageData html: __html__['test/fixtures/renderer-html-doc-click-test-state0.html'], url: url)

    edge-root-state1 = new RenderGraph.Edge root, [new SerializableEvent({type: \click, _constructor-name: \MouseEvent, target: generate-x-path(root.iframe.content-window), bubbles: true})]
    state1 = graph.add (new PageData html: __html__['test/fixtures/renderer-html-doc-click-test-state1.html'], url: url), edge-root-state1

    edge-state1-state2 = new RenderGraph.Edge state1, [new SerializableEvent({type: \click, _constructor-name: \MouseEvent, target: generate-x-path(state1.iframe.content-document), bubbles: true})]
    state2 = graph.add (new PageData html: __html__['test/fixtures/renderer-html-doc-click-test-state2.html'], url: url), edge-state1-state2

    edge-state2-state3 = new RenderGraph.Edge state2, [new SerializableEvent({type: \click, _constructor-name: \MouseEvent, target: '/html/body', bubbles: true})]
    state3 = graph.add (new PageData html: __html__['test/fixtures/renderer-html-doc-click-test-state3.html'], url: url), edge-state2-state3

    results <- Promise.all graph.refresh(filename) .then
    expect results .to.eql [null, null, null, null]

  it 'can be executed multiple times'

  function load-css doc, new-filename, old-filename = \PLACEHOLDER
    # Hack: Change the CSS filename inside renderer iframe to simulate CSS file change
    link = doc.get-element-by-id \css-target
    link.href .= replace old-filename, new-filename

    return link.href