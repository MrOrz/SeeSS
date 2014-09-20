require!{
  './Renderer.ls'
  Promise: bluebird
  './XPathUtil.ls'.queryXPath
  './XPathUtil.ls'.generateXPath
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

      # Reset all BFS taggings. Prepare for BFS.
      renderer-queue = []
      for renderer in @renderers
        delete renderer._graph-prop.bfs-queued

        if renderer._graph-prop.is-source
          # Put source renderers inside render queue
          renderer-queue.push renderer

          # Set bfs properties
          renderer._graph-prop.bfs-src = renderer.page-data.url
          renderer._graph-prop.bfs-queued = true
          renderer._graph-prop.bfs-edges = []
          renderer._graph-prop.bfs-edges-updated-promise = Promise.resolve []

      # Execute the BFS
      refresh-promises = while renderer = renderer-queue.shift!

        # Setting children's BFS properties
        #

        renderer-src = renderer._graph-prop.bfs-src

        children = @children-of renderer .filter (child) -> child.renderer._graph-prop.bfs-queued isnt true

        for child in children
          # Remember the old event target element instances
          if child.in-edge.has-event-targets!
            child.renderer._graph-prop.bfs-old-event-targets = []
            for evt in child.in-edge.events
              old-event-target = renderer.iframe.content-window.document `query-x-path` evt.target
              child.renderer._graph-prop.bfs-old-event-targets.push old-event-target

          # Set bfs properties of children and enqueue each child
          child.renderer._graph-prop.bfs-src = renderer-src
          child.renderer._graph-prop.bfs-queued = true

          renderer-queue.push child.renderer

        # Setting promise-related relationships on children.
        #

        # Make renderer start applying new HTML as soon as possible
        apply-promise = renderer.applyHTML renderer-src, renderer._graph-prop.bfs-edges-updated-promise

        # Update the outgoing edges when new HTML is applied
        edge-updated-promise = apply-promise.then let children = children
          ({mapping, page-diff}) ->

            for child in children
              if child.in-edge.has-event-targets!
                for old-target, idx in child.renderer._graph-prop.bfs-old-event-targets

                  new-target = if old-target.node-type is Node.DOCUMENT_NODE or
                                  old-target.constructor.name is \Window or
                                  old-target.node-name in <[HTML BODY]>
                    # Document node, window node, <html> and <body> will not appear in mapping,
                    # but always mapped to the respective elements in the updated renderer
                    #
                    old-target
                  else
                    mapping.get-node-from old-target

                  if new-target
                    child.in-edge.events[idx].target = generate-x-path new-target
                  else
                    child.in-edge.events[idx].target = '/NOT_EXIST'

        for child in children
          # Resolve to child.renderer._graph-prop.bfs-edges when edge are updated
          edges = child.renderer._graph-prop.bfs-edges = renderer._graph-prop.bfs-edges ++ child.in-edge
          child.renderer._graph-prop.bfs-edges-updated-promise = edge-updated-promise.then let edges = edges
            ->
              edges

        # "refresh promise" pushed into refresh-promises array
        #
        apply-promise.then ({page-diff, mapping}) ->
          page-diff
        .catch let children = children, renderer = renderer
          ->
            console.log '[RenderGraph] Something wrong with renderer', renderer
            # Stop traversing the children if something wrong applying HTML
            #
            i=0
            while i < renderer-queue.length, i+=1 when renderer-queue[i] in children
              child = renderer-queue.splice(i, 1).0

              # make the child can be re-queued by others
              child.bfs-queued = false
            return "Cannot apply HTML to Renderer"

      return refresh-promises

  # Given a renderer or renderer-id, return array of renderers and edges
  #
  children-of: (renderer) ->
    if typeof renderer is \number
      renderer-idx = renderer
      renderer = @renderers[renderer]
    else
      renderer-idx = renderer._graph-prop.id

    children = for own neighbor-id, edge of @adj-list[renderer-idx]
      new Child(edge, @renderers[neighbor-id])

    return children

# The data structure storing data in edge
#
class Edge
  (@from-renderer, @events) ->

  has-event-targets: ->
    @events.length isnt 0 and @events.0.type isnt \WAIT


# The data structure returned by children-of in arrays
#
class Child
  (@in-edge, @renderer) ->



module.exports = RenderGraph
module.exports.Edge = Edge
