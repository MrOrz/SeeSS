require! {
  '../../src/livescript/components/PageData.ls'
  '../../src/livescript/components/RenderGraph.ls'
}

(...) <-! describe \RendererGraph, _

#
# Mock Renderer to avoid real iframe generation
#
class Renderer
  (@page-data) ->

describe '#add', (...) !->
  it "creates renderer instance", ->
    graph = new RenderGraph

    graph.add (new PageData html: '<node0>')
    graph.add (new PageData html: '<node1>'), \edge-0-1
    graph.add (new PageData html: '<node2>'), \edge-1-2

    expect graph.adj-list.0.1 .to.be \edge-0-1
    expect graph.adj-list.1.0 .to.be undefined
    expect graph.adj-list.1.2 .to.be \edge-1-2
    expect graph.adj-list.0.2 .to.be undefined

  it "recognizes and reuses duplicated renderer instance", ->
    graph = new RenderGraph

    # Visit order: 0 -> 1 -> 0 -> 2 -> 3 -> 0
    #
    graph.add (new PageData html: '<node0>')
    graph.add (new PageData html: '<node1>'), \edge-0-1
    graph.add (new PageData html: '<node0>'), \edge-1-0
    graph.add (new PageData html: '<node2>'), \edge-0-2
    graph.add (new PageData html: '<node3>'), \edge-2-3
    graph.add (new PageData html: '<node0>'), \edge-3-0

    # There should be only node 0~3
    expect graph.renderers.length .to.be 4
    expect graph.adj-list.4 .to.be undefined

describe '#refresh', (...) !->