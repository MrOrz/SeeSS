require! {
  '../../src/livescript/components/PageData.ls'
  '../../src/livescript/components/RenderGraph.ls'
}

(...) <-! describe \RendererGraph, _

describe '#add', (...) !->
  it "creates renderer instance", ->
    graph = new RenderGraph document.body

    renderer0 = graph.add (new PageData html: '<node0>')
    renderer1 = graph.add (new PageData html: '<node1>'), (new RenderGraph.Edge renderer0, \edge-0-1)
    renderer2 = graph.add (new PageData html: '<node2>'), (new RenderGraph.Edge renderer1, \edge-1-2)

    expect graph.adj-list.0.1.event .to.be \edge-0-1
    expect graph.adj-list.1.0 .to.be undefined
    expect graph.adj-list.1.2.event .to.be \edge-1-2
    expect graph.adj-list.0.2 .to.be undefined

  it "recognizes and reuses duplicated renderer instance", ->
    graph = new RenderGraph document.body

    # Visit order: 0 -> 1 -> 0 -> 2 -> 3 -> 0
    #
    renderer0 = graph.add (new PageData html: '<node0>')
    renderer1 = graph.add (new PageData html: '<node1>'), (new RenderGraph.Edge renderer0, \edge-0-1)
    graph.add (new PageData html: '<node0>'), (new RenderGraph.Edge renderer1, \edge-1-0)
    renderer2 = graph.add (new PageData html: '<node2>'), (new RenderGraph.Edge renderer0, \edge-0-2)
    renderer3 = graph.add (new PageData html: '<node3>'), (new RenderGraph.Edge renderer2, \edge-2-3)
    graph.add (new PageData html: '<node0>'), (new RenderGraph.Edge renderer3, \edge-3-0)

    # There should be only node 0~3
    expect graph.renderers.length .to.be 4
    expect graph.adj-list.4 .to.be undefined

describe '#neighbors-of', (...) !->
  it 'returns correct neighbors', ->
    graph = new RenderGraph document.body

    renderer0 = graph.add (new PageData html: '<node0>')
    renderer1 = graph.add (new PageData html: '<node1>'), (new RenderGraph.Edge renderer0, \edge-0-1)
    renderer2 = graph.add (new PageData html: '<node2>'), (new RenderGraph.Edge renderer1, \edge-1-2)

    neighbor0 = graph.neighbors-of 0

    expect neighbor0.length .to.eql 1
    expect neighbor0.0.edge.event .to.be \edge-0-1
    expect neighbor0.0.renderer.page-data.html .to.be '<node1>'

    neighbor1 = graph.neighbors-of 1

    expect neighbor1.length .to.eql 1
    expect neighbor1.0.edge.event .to.be \edge-1-2
    expect neighbor1.0.renderer.page-data.html .to.be '<node2>'

    neighbor2 = graph.neighbors-of 2

    expect neighbor2.length .to.eql 0


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

    # There should be 2 renderers
    expect results.length .to.be 2

    for page-diff in results
      # For all renderers,
      # there should be only one ElementDifference that reports
      # the color of h1 changed from blue to red.
      #
      expect page-diff.diffs.length .to.be 1
      expect page-diff.diffs.0.elem.node-name .to.be \H1
      expect page-diff.diffs.0.computed.color.before .to.be "rgb(0, 0, 255)"
      expect page-diff.diffs.0.computed.color.after .to.be "rgb(255, 0, 0)"

  function load-css doc, new-filename, old-filename = \PLACEHOLDER
    # Hack: Change the CSS filename inside renderer iframe to simulate CSS file change
    link = doc.get-element-by-id \css-target
    link.href .= replace old-filename, new-filename

    return link.href