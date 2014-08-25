require!{
  './Renderer.ls'
}

# A directed graph for renderers
#
class RenderGraph
  (@iframe-container) ->
    # Renderer array, renderer-id --> renderer object instance
    #
    @renderers = []

    # @adj-list[renderer1][renderer2] === edge
    #
    # edge is an user action event, thus it is directed.
    #
    @adj-list = {}

  #
  # Add a renderer node given the page-data and edge,
  # return the new renderer node.
  #
  add: (page-data, edge) ->

    # Check if the page already exists in a renderer
    #
    renderer-idx = null

    for renderer, idx in @renderers
      if renderer.page-data.html is page-data.html
        renderer-idx = idx
        break

    if renderer-idx is null

      # The page is not in any existing renderer, create one.
      #
      renderer-idx = @renderers.length
      @renderers ++= new Renderer page-data

      # Record the position of the renderer for quick access when fetching its neighbors.
      # Also saves whether the renderer is a source node
      # (The page is recorded after refresh)
      #
      @renderers[renderer-idx]._graph-prop =
        id: renderer-idx
        is-source: !edge

      # Invoke renderer's render so that iframe can start rendering
      @renderers[renderer-idx].render @iframe-container

      # Initialize adj-list of the renderer
      @adj-list[renderer-idx] = {}

    renderer = @renderers[renderer-idx]

    # Skip the following step if there is no edge
    return renderer unless edge


    # Managing adjacent list
    #
    referrer-idx = edge.from-renderer._graph-prop.id
    @adj-list[referrer-idx][renderer-idx] = edge

    return renderer

  #
  # Receives Livereload reload events, determine whether it is a stylesheet change
  # or an HTML change.
  #
  # If is a stylesheet change, invoke #applyCSS to all renderers.
  #
  # If otherwise, refresh all source renderers from server,
  # then traverse the render graph using the original visiting order,
  # while replaying the events and refreshing the other non-source renderers.
  #
  refresh: ->
    ...
# The data structure storing data in edge
#
class Edge
  (@from-renderer, @action, @target) ->

# The data structure returned by neighbors-of in arrays
#
class Neighbor
  (@edge, @renderer) ->



module.exports = RenderGraph
module.exports.Edge = Edge
