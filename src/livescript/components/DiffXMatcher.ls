# Performs diffX Algorithm to find the mapping between the old-tree and the new-tree.
#
# Ref-- diffX: an algorithm to detect changes in multi-version XML documents
# http://dl.acm.org/citation.cfm?id=1105635
#

class DiffXMatcher
  # The constructor of DiffXMatcher.
  # diffX is used as soon as a matcher is instantiated.
  #
  # @old-tree and @new-tree are Document elements.
  # (https://developer.mozilla.org/en-US/docs/Web/API/document)
  #
  (@old-tree, @new-tree) ->
    @_map = _mapping @old-tree, @new-tree

  # Get the corresponding old node from the new.
  #
  to-old-node: (new-node) ->
    @_map.find-x new-node

  # Get the corresponding new node from the old.
  #
  to-new-node: (old-node) ->
    @_map.find-y old-node

  # diffX Algorithm 1 (Isolated Tree Fragment Mapping)
  # Input t1, t2 : tree, which are essentially root nodes
  # Output m : map
  #
  function _mapping (t1, t2, m = new MapSet)
    # index the nodes of t2
    t2-index = _index-nodes t2

    # traverse t1 in a level-order sequence
    level-order-iterator = _LevelOrderIterator(t1)
    until (it = level-order-iterator.next!).done
      # let x be the current node
      x = it.value

      if m.has x
        continue # skip current node

      # let y[] be all nodes from t2 equal to x
      ys = _all-indexed-nodes-equal-to x, t2-index
      mpp = new MapSet
      for y in ys when !m.has(null, y)
        mp = new MapSet
        _match-fragment x, y, m, mp
        mpp = mp if mp.size! > mpp.size!

      m.merge mpp

    return m

  # diffX Algorithm 1 (Isolated Tree Fragment Mapping)
  # Input x, y: node, m: map
  # Output mp : map
  !function _match-fragment x, y, m, mp
    if !m.has(x) and !m.has(null, y) and _node-equal(x, y)
      mp.add x, y

      # for i = 1 to minimum of number of children between x and y
      x-children = _node-children x
      y-children = _node-children y
      for i from 0 to Math.min(x-children.length, y-children.length)-1
        _match-fragment x-children[i], y-children[i], m, mp

  #
  # Helper functions required by diffX algorithm
  #

  # An iterator generator that traverses a DOM tree from root-node in a level-order sequence,
  # which is essentially BFS of a tree.
  #
  # Iterator protocol: http://goo.gl/kcgoFi
  #
  function _LevelOrderIterator root-node
    queue = [root-node]

    return do
      next: ->
        current-node = queue.shift!
        queue ++= _node-children current-node

        return do
          value: current-node
          done: queue.length == 0

  # Returns an array of child nodes, including element, attribute and text nodes.
  # Do not include other nodes like comment nodes.
  #
  function _node-children x
    #
    # Node.ELEMENT_NODE   is 1
    # Node.ATTRIBUTE_NODE is 2
    # Node.TEXT_NODE      is 3
    #
    if x.node-type is Node.ELEMENT_NODE
      return Array::slice.call(x.attributes) ++ Array::filter.call(x.child-nodes, (node)->node.node-type <= 3)
    else
      # Text nodes and attribute nodes are leaf nodes
      return []

  # Extracts label from a node x, as specified in section 3.1 Data Model
  # in the diffX paper.
  #
  function _node-label x
    switch x.node-type
    | Node.ELEMENT_NODE => x.node-name
    | Node.TEXT_NODE => x.node-value
    | Node.ATTRIBUTE_NODE => "#{x.node-name}=#{x.value}"
    | _ => throw new Error("Unsupported node type #{x.node-type} for #{x}")

  # A comparator that checks if a node x equals node y,
  # as specified in section 3.1 Data Model in the diffX paper.
  #
  function _node-equal x, y
    return x.node-type is y.node-type and _node-label(x) is _node-label(y)

  # Generates index of a DOM tree t,
  # mapping node-type and node-label to a node array.
  #
  # The index is later consumed by the method _all-indexed-nodes-equal-to.
  #
  function _index-nodes t
    idx = {}
    idx[Node.ELEMENT_NODE] = {}; idx[Node.TEXT_NODE] = {}; idx[Node.ATTRIBUTE_NODE] = {}
    walker = document.create-tree-walker t, NodeFilter.SHOW_ELEMENT .|. NodeFilter.SHOW_TEXT

    do
      current-node = walker.current-node
      arr = idx[current-node.node-type][_node-label(current-node)] ?= []
      arr.push current-node

      if current-node.node-type is Node.ELEMENT_NODE and current-node.attributes.length > 0
        for attribute-node in current-node.attributes
          arr = idx[Node.ATTRIBUTE_NODE][_node-label(attribute-node)] ?= []
          arr.push attribute-node

    while walker.next-node!

    return idx

  # Get nodes that equals to the node x from the index.
  #
  # The index was generated from the method _index-nodes
  #
  function _all-indexed-nodes-equal-to x, idx
    return idx[x.node-type][_node-label(x)] || []

# Helper class
# A set of ordered pairs (x, y), where x is a node of t1 and y is a node of t2.
#
class MapSet
  ->
    @_keys = [] # For merging
    @_map = new WeakMap
    @_reverse-map = new WeakMap

  size: ->
    @_keys.length

  add: (x, y) ->
    return if @_map.has x

    @_keys.push x
    @_map.set x, y
    @_reverse-map.set y, x

  # Merge in another MapSet instance m
  merge: (m) !->
    for x in m._keys
      @add x, m.find-y(x)

  # See if (x, y) mapping belongs to the set.
  # If x or y is null, it is considered to be a wildcard.
  #
  has: (x = null, y = null) ->
    if x isnt null and y isnt null
      return @_map.get(x) is y
    else if x is null and y isnt null
      return @_reverse-map.get(y) isnt undefined
    else if x isnt null and y is null
      return @_map.get(x) isnt undefined
    else
      throw new Error "Either x or y must be specified!"

  find-x: (y) ->
    @_reverse-map.get y

  find-y: (x) ->
    @_map.get x


module.exports = DiffXMatcher
module.exports.MapSet = MapSet # For testing
