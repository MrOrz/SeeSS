# Algorithms that finds the mapping between the old-tree and the new-tree
#

# The basic diffX algorithm (Algorithm 1 in diffX paper)
# Reference -- diffX: an algorithm to detect changes in multi-version XML documents
# http://dl.acm.org/citation.cfm?id=1105635
#
# Variable names are directly adopted from the pseudo-code in the paper.
#
# Input T1, T2 : tree, which are essentially DOM Node instances.
# Output m : TreeTreeMap instance that maps the nodes between T1 and T2
#
function diffX (T1, T2, M = new TreeTreeMap)

  # index the nodes of T2
  t2-index = generate-index T2

  # traverse T1 in a level-order sequence
  level-order-iterator = LevelOrderIterator(T1)
  until (it = level-order-iterator.next!).done
    # let x be the current node
    x = it.value

    if M.has x
      continue # skip current node

    # let y[] be all nodes from T2 equal to x
    ys = equal-nodes-by-index x, t2-index
    Mpp = new TreeTreeMap
    for y in ys when !M.has(null, y)
      Mp = new TreeTreeMap
      match-fragment x, y, M, Mp
      Mpp = Mp if Mp.size! > Mpp.size!

    M.merge Mpp

  return M


# Recursive part of basic diffX Algorithm
# Input x, y: node, m: map
# Output mp : map
#
!function match-fragment x, y, M, Mp
  if !M.has(x) and !M.has(null, y) and equals(x, y)
    Mp.add x, y

    # for i = 1 to minimum of number of children between x and y
    x-children = children-of x
    y-children = children-of y
    for i from 0 to Math.min(x-children.length, y-children.length)-1
      match-fragment x-children[i], y-children[i], M, Mp

# Valeiente's bottom-up mapping algoritm
# Reference: An Efficient Bottom-Up Distance between Trees
# http://www.cs.upc.edu/~valiente/abs-spire-2001.html
#
# Variable names are directly adopted from the pseudo-code in the paper.
#
# Input T1, T2 : tree, which are essentially DOM Node instances.
# Output m : TreeTreeMap instance that maps the nodes between T1 and T2
#
function valiente (T1, T2, M = new TreeTreeMap)
  G = new DAG # The compacted directed acyclic graph representation of T1 and T2
  K = new WeakMap # A map of nodes of T1 and T2 to nodes of G

  compact T1, T2, G, K
  mapping T1, T2, K, M

# Procedure "compact" in Valeiente's paper
#
# Input T1, T2: tree, g: graph
# Output k : map of nodes of T1 and T2 to nodes of G
#
!function compact T1, T2, G, K
  ...

# Procedure "mapping" in Valeiente's paper
#
# Input T1, T2: tree, g: graph
# Output m : TreeTreeMap instance that maps the nodes between T1 and T2
#
!function mapping T1, T2, K, M
  ...

# Mapping a node x in a tree to its corresponding node y in another tree.
#
class TreeTreeMap
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

  # Merge in another TreeTreeMap instance ttmap
  merge: (ttmap) !->
    for x in ttmap._keys
      @add x, ttmap.get-node-from(x)

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


exports <<< {TreeTreeMap, diffX, valiente}


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

# Directed Acyclic Graph used in Valiente's bottom-up algorithm
#
class DAG

  ->
    @_nodes = []

  # Returns the new Node's instance
  #
  add-node: (label, height=0)->
    @_nodes.push new DAGNode(label, height, @, @_nodes.length)

  # The Graph Nodes in DAG
  #
  class DAGNode
    (@label, @height, @_graph, @_idx)->
      @_child-idx = [] # An array of DAGNode index in parent DAG _nodes array

    # Return an array of references pointing to the DAGNode instances
    #
    children: ->
      @_child-idx.map (idx) ~> @_graph._nodes[idx]

    # Return how many children the DAGnode has
    #
    outdegree: ->
      @_child-idx.length

    # Add a DAGNode instance as a child
    #
    add-child: (dag-node) ->
      @_child-idx.push dag-node._idx

# Mapping a node in a tree to the corresponding node in a DAG instance.
#
class TreeDAGMap
  ->
    ...
