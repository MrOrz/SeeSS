require!{
  './Renderer.ls'
}

# A directed graph for renderers
#
class RenderGraph
  ->
    # Renderer array, renderer-id --> renderer object instance
    #
    @renderers = []

    # @adj-list[renderer1][renderer2] === edge-data
    #
    # edge-data is an user action event, thus it is directed.
    #
    @adj-list = {}

  #
  # Add a renderer node given the page-data and edge-data
  #
  add: (page-data, edge-data) ->

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
        is-source: !edge-data

      # Initialize adj-list of the renderer
      @adj-list[renderer-idx] = {}

    renderer = @renderers[renderer-idx]

    referrer-idx = renderer-idx - 1
    referrer = @renderers[referrer-idx]

    # Skip the following step if there is no referrer renderer
    return if not referrer or renderer._graph-prop.is-source

    # Managing adjacent list
    #
    @adj-list[referrer-idx][renderer-idx] = edge-data

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

module.exports = RenderGraph
