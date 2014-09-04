# Algorithms that finds the mapping between the old-tree and the new-tree
#


# The basic diffX algorithm (Algorithm 1 in diffX paper)
# Reference -- diffX: an algorithm to detect changes in multi-version XML documents
# http://dl.acm.org/citation.cfm?id=1105635
#
# Input t1, t2 : tree, which are essentially DOM Node instances.
# Output m : map
#
function diffX (t1, t2, m = new MapSet)

  # index the nodes of t2
  t2-index = generate-index t2

  # traverse t1 in a level-order sequence
  level-order-iterator = LevelOrderIterator(t1)
  until (it = level-order-iterator.next!).done
    # let x be the current node
    x = it.value

    if m.has x
      continue # skip current node

    # let y[] be all nodes from t2 equal to x
    ys = equal-nodes-by-index x, t2-index
    mpp = new MapSet
    for y in ys when !m.has(null, y)
      mp = new MapSet
      match-fragment x, y, m, mp
      mpp = mp if mp.size! > mpp.size!

    m.merge mpp

  return m


# recursive part of basic diffX Algorithm
# Input x, y: node, m: map
# Output mp : map
#
!function match-fragment x, y, m, mp
  if !m.has(x) and !m.has(null, y) and equals(x, y)
    mp.add x, y

    # for i = 1 to minimum of number of children between x and y
    x-children = children-of x
    y-children = children-of y
    for i from 0 to Math.min(x-children.length, y-children.length)-1
      match-fragment x-children[i], y-children[i], m, mp

#
#
#
function valiente (t1, t2, m = new MapSet)
  ...


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
      @add x, m.get-node-from(x)

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

  # Returns node x that maps to y
  #
  get-node-to: (y) ->
    @_reverse-map.get y

  # Returns node y that maps from x
  #
  get-node-from: (x) ->
    @_map.get x


exports <<< {MapSet, diffX, valiente}


#
# Helper functions required by diffX and Valiente algorithm
#

# An iterator generator that traverses a DOM tree from root-node in a level-order sequence,
# which is essentially BFS of a tree.
#
# Iterator protocol: http://goo.gl/kcgoFi
#
function LevelOrderIterator root-node
  queue = [root-node]

  return do
    next: ->
      current-node = queue.shift!
      queue ++= children-of current-node

      return do
        value: current-node
        done: queue.length == 0

# Returns an array of child nodes, including element, attribute and text nodes.
# Do not include other nodes like comment nodes.
#
function children-of x
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
function label-of x
  switch x.node-type
  | Node.ELEMENT_NODE => x.node-name
  | Node.TEXT_NODE => x.node-value
  | Node.ATTRIBUTE_NODE => "#{x.node-name}=#{x.value}"
  | _ => throw new Error("Unsupported node type #{x.node-type} for #{x}")

# A comparator that checks if a node x equals node y,
# as specified in section 3.1 Data Model in the diffX paper.
#
function equals x, y
  return x.node-type is y.node-type and label-of(x) is label-of(y)

# Generates index of a DOM tree t,
# mapping node-type and node-label to a node array.
#
# The index is later consumed by the method equal-nodes-by-index.
#
function generate-index t
  idx = {}
  idx[Node.ELEMENT_NODE] = {}; idx[Node.TEXT_NODE] = {}; idx[Node.ATTRIBUTE_NODE] = {}
  walker = document.create-tree-walker t, NodeFilter.SHOW_ELEMENT .|. NodeFilter.SHOW_TEXT

  do
    current-node = walker.current-node
    arr = idx[current-node.node-type][label-of(current-node)] ?= []
    arr.push current-node

    if current-node.node-type is Node.ELEMENT_NODE and current-node.attributes.length > 0
      for attribute-node in current-node.attributes
        arr = idx[Node.ATTRIBUTE_NODE][label-of(attribute-node)] ?= []
        arr.push attribute-node

  while walker.next-node!

  return idx

# Get nodes that equals to the node x from the index.
#
# The index was generated from the method generate-index
#
function equal-nodes-by-index x, idx
  return idx[x.node-type][label-of(x)] || []
