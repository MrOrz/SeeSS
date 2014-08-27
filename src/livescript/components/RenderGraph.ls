require!{
  './Renderer.ls'
  Promise: bluebird
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
      @renderers.push new Renderer page-data

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

    if edge
      # Managing adjacent list
      #
      referrer-idx = edge.from-renderer._graph-prop.id
      @adj-list[referrer-idx][renderer-idx] = edge

    return renderer

  #
  # Receives Livereload reload events, determine whether it is a stylesheet change
  # or an HTML change.
  # The determination process is identical to the one in Livereload Reloader class.
  #
  # If is a stylesheet change, invoke #applyCSS to all renderers.
  #
  # If otherwise, refresh all source renderers from server,
  # then traverse the render graph using the original visiting order,
  # while replaying the events and refreshing the other non-source renderers.
  #
  # #refresh returns an array of promises, each of which resolves to the changes
  # for a renderer.
  #
  refresh: (path) ->
    if path.match /\.css$/i
      # Style change, invoke applyCSS!
      return [renderer.applyCSS path for renderer in @renderers]

    else
      # BFS renderer queue
      renderer-queue = []

      # Create a simulating iframe for each source iframe,
      # and reset all BFS taggings
      for renderer in @renderers
        delete renderer._graph-prop.bfs-visited
        delete renderer._graph-prop.bfs-iframe

        if renderer._graph-prop.is-source
          # Put source renderers inside render queue
          renderer-queue.push renderer

          # Create iframe for source renderers
          renderer._graph-prop.bfs-iframe = document.create-element \iframe

          let iframe = renderer._graph-prop.bfs-iframe, page-data = renderer.page-data
            iframe.width = page-data.width
            iframe.height = page-data.height

            # Source renderer use src attribute to load data.
            #
            iframe.src = page-data.url
            iframe.onload = ->
              iframe.onload = null
              ...

            # Start iframe loading
            #
            @iframe-container.insert-before iframe, null


      # Execute the BFS
      while renderer = renderer-queue.unshift!
        # If not source renderer, there must be an edge from the previous renderer
        unless renderer._graph-prop.is-source
          current-renderer-idx = renderer._graph-prop.id
          previous-renderer-idx = @renderers[visiting-order-idx-1]._graph-prop.id
          edge = @adj-list[previous-renderer-idx][current-renderer-idx]
        ...

  # Given a renderer or renderer-id, return array of renderers and edges
  #
  neighbors-of: (renderer) ->
    if typeof renderer is \number
      renderer-idx = renderer
      renderer = @renderers[renderer]
    else
      renderer-idx = renderer._graph-prop.id

    neighbors = for own neighbor-id, edge of @adj-list[renderer-idx]
      new Neighbor(edge, @renderers[neighbor-id])

    return neighbors

# The data structure storing data in edge
#
class Edge
  (@from-renderer, @event) ->

# The data structure returned by neighbors-of in arrays
#
class Neighbor
  (@edge, @renderer) ->



module.exports = RenderGraph
module.exports.Edge = Edge
