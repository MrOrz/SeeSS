# Algorithms that finds the mapping between the old-tree and the new-tree
#
# [Notice] TreeWalker should not be used in this module, since in our data model,
# element attributes are considered to be childrens, but there is no way they appear
# during a TreeWalker traversal.
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
  until (cursor = level-order-iterator.next!).done
    # let x be the current node
    x = cursor.value

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
  if !M.has(x) and !M.has(null, y) and node-equal(x, y)
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
  K = new TreeDAGMap # A map of nodes of T1 and T2 to nodes of G

  compact T1, T2, G, K
  mapping T1, T2, K, M

  return M


# Procedure "compact" in Valeiente's paper
#
# Input T1, T2: tree, G: graph
# Output K : TreeDAGMap instance that maps nodes of T1 and T2 to nodes of G
#
!function compact T1, T2, G, K

  # First, calculate the height of each node in T1 and T2.
  height = new WeakMap  # Maps a tree node to the height
  compute-height T1, height
  compute-height T2, height

  # Initialization of G and chidren[]
  #
  # Combine the loop in line 3-7 and line 9-14 in Figure 6 alltogether
  #
  children = new WeakMap  # Maps a tree node to unprocessed child count, which may be edited
  outdegree = new WeakMap # Maps a tree node to child count, which is constant if tree structures doesn't change
  L = {} # Map of node label to nodes of G
  Q = [] # A queue of nodes of T1 & T2

  for iterator in [PreorderIterator(T1), PreorderIterator(T2)]

    until (cursor = iterator.next!).done
      v = cursor.value

      children-count = children-count-of v
      outdegree.set v, children-count
      children.set v, children-count

      if children-count is 0
        Q.push v

        leaf-label = label-of v

        # Only add-node once for each leaf-label
        if L[leaf-label] is undefined
          L[leaf-label] = G.add-node leaf-label

  do
    # console.log '[valiente#compact] Q:', Q.map -> label-of it .replace /[\n|\r]/g, ''
    # console.log '[valiente#compact] G:', G._nodes.map -> "<#{it.label.replace(/[\n|\r]/g,'')} #{it.height} [#{it._child-idx}]>"
    v = Q.shift!

    if outdegree.get(v) is 0
      K.add v, L[label-of v]

    else
      found = false

      iterator = G.generate-reverse-iterator!
      until (cursor = iterator.next!).done
        w = cursor.value

        if height.get(v) isnt w.height
          break

        if outdegree.get(v) != w.outdegree! or label-of(v) != w.label
          continue

        V = children-of v .map -> K.get-node-from it
        W = w.children!

        if array-equal V, W
          K.add v, w
          found = true
          break

      if not found
        v-label = label-of v
        w = G.add-node v-label, height.get v
        K.add v, w

        for u in children-of v
          w.add-child K.get-node-from u

    unless is-root v
      v-parent = parent-of v

      children-count = children.get(v-parent) - 1
      children.set v-parent, children-count

      if children-count is 0
        Q.push v-parent

  until Q.length is 0

# Procedure "mapping" in Valeiente's paper
#
# Input T1, T2: tree, K: TreeDAGMap instance
# Output M : TreeTreeMap instance that maps the nodes between T1 and T2
#
!function mapping T1, T2, K, M

  # Get the right most node in T2, and calculate the preorder of each node in T2
  preorder = new WeakMap

  var rightmost-in-t2
  t2-iterator = PreorderIterator T2
  t2-idx = 0
  until (cursor = t2-iterator.next!).done
    preorder.set cursor.value, t2-idx
    t2-idx += 1
    rightmost-in-t2 = cursor.value

  t2-document = T2.owner-document # To see if a node is in T2

  # Start algorithm
  iterator = LevelOrderIterator T1
  until (cursor = iterator.next!).done
    v = cursor.value
    Kv = K.get-node-from v # K[v], the mapped graph node from tree node v

    if M.get-node-from(v) is undefined
      w = rightmost-in-t2

      U = K.get-nodes-to(Kv)
      for u in U when u.owner-document is t2-document
        if M.get-node-to(u) is undefined and preorder.get(u) < preorder.get(w)
          w = u

      if Kv is K.get-node-from w
        t1-iterator = PreorderIterator v
        t2-iterator = PreorderIterator w

        until (cursor1 = t1-iterator.next!).done or (cursor2 = t2-iterator.next!).done
          M.add cursor1.value, cursor2.value


# Mapping a node x in a tree to its corresponding node y in another tree.
#
class TreeTreeMap
  ->
    @_keys = [] # For merging
    @_map = new WeakMap
    @_reverse-map = new WeakMap

  size: ->
    @_keys.length

  # Add a mapping that maps node x in a tree to node y in another tree
  #
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


# Mapping a node in a tree to the corresponding node in a DAG instance.
#
class TreeDAGMap
  ->
    @_map = new WeakMap
    @_reverse-map = new WeakMap

  # Add a mapping that maps a tree node to a DAGNode instance
  #
  add: (tree-node, dag-node) ->
    return if @_map.has tree-node

    @_map.set tree-node, dag-node

    if @_reverse-map.has dag-node
      @_reverse-map.get dag-node .push tree-node
    else
      @_reverse-map.set dag-node, [tree-node]

  # Returns an array of tree nodes that maps to specified tree node
  #
  get-nodes-to: (dag-node) ->
    @_reverse-map.get dag-node or []

  # Returns the DAGNode instance that maps from specified tree node
  #
  get-node-from: (tree-node) ->
    @_map.get tree-node


# Directed Acyclic Graph used in Valiente's bottom-up algorithm
#
class DAG

  ->
    @_nodes = []

  # Returns the new Node's instance
  #
  add-node: (label, height=0)->
    new-node = new DAGNode(label, height, @, @_nodes.length)
    @_nodes.push new-node
    return new-node

  generate-reverse-iterator: ->
    idx = @_nodes.length

    return do
      next: ~>
        idx -= 1
        current-node = @_nodes[idx]

        return do
          value: current-node
          done: idx < 0

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


exports <<< {TreeTreeMap, TreeDAGMap, DAG, diffX, valiente}


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
      if queue.length is 0
        return done: true
      else
        current-node = queue.shift!
        queue ++= children-of current-node

        return do
          value: current-node
          done: false

# An iterator generator that performs a preorder traversal on a DOM tree using,
# which is essentially DFS of a tree.
#
# Iterator protocol: http://goo.gl/kcgoFi
#
function PreorderIterator root-node
  stack = [root-node]

  return do
    next: ->
      if stack.length is 0
        return done: true
      else
        current-node = stack.pop!
        stack ++= children-of current-node .reverse!

        return do
          value: current-node
          done: false

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

function parent-of x
  if x.node-type is Node.ATTRIBUTE_NODE
    return x.owner-element
  else
    return x.parent-node

function children-count-of x
  if x.node-type is Node.ELEMENT_NODE
    return x.attributes.length + Array::filter.call(x.child-nodes, (node)->node.node-type <= 3).length
  else
    # Text nodes and attribute nodes are leaf nodes
    return 0

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
function node-equal x, y
  return x.node-type is y.node-type and label-of(x) is label-of(y)

# Generates index of a DOM tree t,
# mapping node-type and node-label to a node array.
#
# The index is later consumed by the method equal-nodes-by-index.
#
function generate-index t
  idx = {}
  idx[Node.ELEMENT_NODE] = {}; idx[Node.TEXT_NODE] = {}; idx[Node.ATTRIBUTE_NODE] = {}
  iterator = PreorderIterator t

  until (cursor = iterator.next!).done
    current-node = cursor.value
    arr = idx[current-node.node-type][label-of(current-node)] ?= []
    arr.push current-node

    if current-node.node-type is Node.ELEMENT_NODE and current-node.attributes.length > 0
      for attribute-node in current-node.attributes
        arr = idx[Node.ATTRIBUTE_NODE][label-of(attribute-node)] ?= []
        arr.push attribute-node


  return idx

# Get nodes that equals to the node x from the index.
#
# The index was generated from the method generate-index
#
function equal-nodes-by-index x, idx
  return idx[x.node-type][label-of(x)] || []


# Recursively calculate the height of the current node,
# which by definition is the largest distance from the leaves of the subtree
# that roots the current node.
#
# Output height-map : Maps a tree node to its height
#
# http://www.csie.ntnu.edu.tw/~u91029/Tree.html
#
function compute-height current-node, height-map
  height = 0

  for child in children-of current-node
    h = 1 + compute-height child, height-map
    height = h if height < h

  # Set output
  height-map.set current-node, height

  return height # Recursive return


# Returns if two lists of DAGNode are equal
#
function array-equal nodes1, nodes2
  return false if nodes1.length isnt nodes2.length

  for node1, idx in nodes1
    node2 = nodes2[idx]

    return false if node1 isnt node2

  return true

# Returns if a TreeNode is the root of the tree
#
function is-root node
  parent-of(node) is node.owner-document
