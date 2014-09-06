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
# Procedure Mapping(T1, T2, M) in the paper.
#
# Input T1, T2 : tree, which are essentially DOM Node instances.
# Output ttmap : TreeTreeMap instance that maps the nodes between T1 and T2.
#                Argument `M` in the paper.
#
# Let (L##-##) denotes the line number of the pseudo-code of procedure Mapping
# in diffX paper.
#
function diffX (T1, T2, ttmap = new TreeTreeMap)

  # index the nodes of T2
  t2-index = generate-index T2

  # traverse T1 in a level-order sequence
  # (L6-23)
  #
  level-order-iterator = LevelOrderIterator(T1)
  until (cursor = level-order-iterator.next!).done
    current-node = cursor.value     # variable `x` in the paper

    if ttmap.has current-node
      continue # skip current node

    # Match current node with candidates from T2.
    #
    candidates = equal-nodes-by-index current-node, t2-index # variable `y[]` in the paper
    optimal-ttmap = new TreeTreeMap # variable `M"` in the paper

    # (L13-21)
    #
    for candidate in candidates when !ttmap.has(null, candidate)
      new-ttmap = new TreeTreeMap   # variable `M'` in the paper
      match-fragment current-node, candidate, ttmap, new-ttmap
      optimal-ttmap = new-ttmap if new-ttmap.size! > optimal-ttmap.size!

    ttmap.merge optimal-ttmap

  return ttmap


# Recursive part of basic diffX Algorithm, recursively maps 2 subtrees rooted at
# tree-node 1 and tree-node 2 and return the subtree mapping.
#
# tree-node1 comes from the tree T1 and tree-node2 comes from the tree T2.
#
# Procedure Match-Fragment(x, y, M, M') in the paper.
#
# Input tree-node1, tree-node2: node, ttmap: global TreeTreeMap instance.
#       Argument x, y, M in the paper, respectively.
# Output subtree-ttmap : TreeTreeMap instance that maps the nodes of subtrees rooted at
#                        tree-node1 to subtrees rooted at tree-node2.
#                        Argument M' in the paper.
#
# Let (L##-##) denotes the line number of the pseudo-code of procedure Match-Fragment
# in diffX paper.
#
!function match-fragment tree-node1, tree-node2, ttmap, subtree-ttmap
  if !ttmap.has(tree-node1) and !ttmap.has(null, tree-node2) and node-equal(tree-node1, tree-node2)
    subtree-ttmap.add tree-node1, tree-node2

    # Loop through the tree nodes of tree-node1 and tree-node 2.
    #
    # Notice that the mapping here is pretty rough; it matches the nodes
    # if they are in the same positions among their respective siblings in
    # a top-down fashion, without matching their children first.
    #
    # The paper states that using Valiente's bottom-up algorithm beforehands
    # may improve, since the bottom-up algorithm can match the identical subtrees
    # from the leaves.
    #
    # (L31-33)
    #
    node1-children = children-of tree-node1
    node2-children = children-of tree-node2
    for i from 0 to Math.min(node1-children.length, node2-children.length)-1
      match-fragment node1-children[i], node2-children[i], ttmap, subtree-ttmap

# Valiente's bottom-up mapping algoritm
# Reference: An Efficient Bottom-Up Distance between Trees
# http://www.cs.upc.edu/~valiente/abs-spire-2001.html
#
# Variable names are directly adopted from the pseudo-code in the paper.
#
# Input T1, T2 : tree, which are essentially DOM Node instances.
# Output ttmap : TreeTreeMap instance that maps the nodes between T1 and T2
#
# Let (L##-##) denotes the line number of the pseudo-code of procedure Match-Fragment
# in diffX paper.
#
function valiente (T1, T2, ttmap = new TreeTreeMap)
  # The compacted directed acyclic graph representation of T1 and T2
  graph = new DAG         # variable `G` in the paper

  tdmap = new TreeDAGMap  # variable `K` in the paper

  compact T1, T2, graph, tdmap
  mapping T1, T2, tdmap, ttmap

  return ttmap

# Compacting tree T1 and T2 into a directed acyclic graph (DAG).
# The DAG is the compacted representation of the two tree T1 and T2.
# It should fulfill Definition 7 in Valiente's paper, which is as follows:
#
#   Definition 7. Let F be a forest. The compacted representation of F
#   is a directed acyclic graph G such that a node [v] of G is an equivalence
#   class of nodes of F , where two nodes u and v are equivalent if, and
#   only if, the subtree of F rooted at u and the subtree of F rooted at v
#   are isomorphic, and there is a directed edge from node [u] to node [v]
#   in G if, and only if, there exist nodes u and v in some rooted tree T
#   of F such that v is a child of u in T.
#
#
# Procedure "compact(T1, T2, G, K)" in Valeiente's paper.
#
# Input T1, T2: tree
# Output graph: resulting DAG
#               Argument G in the paper
# Output tdmap : TreeDAGMap instance that maps nodes of T1 and T2 to DAGNode instances
#                Argument K in the paper
#
# Let (L##-##) denotes the line number of the pseudo-code of procedure compact
# in diffX paper.
#
!function compact T1, T2, graph, tdmap

  # First, calculate the height of each node in T1 and T2.
  height = new WeakMap  # Maps a tree node to the height
  compute-height T1, height
  compute-height T2, height

  # Initialization of G and chidren[]
  #
  # (L3-7, L9-14)
  # Combine the loop in line 3-7 and line 9-14 in Figure 6 alltogether
  #
  children = new WeakMap  # Maps a tree node to unprocessed child count, which may be edited
  outdegree = new WeakMap # Maps a tree node to child count, which is constant if tree structures doesn't change
  label-to-graph-node = {} # Map of node label to graph nodes. Variable `L` in the paper.
  queue = [] # A queue of nodes of T1 & T2. Variable `Q` in the paper.

  for iterator in [PreorderIterator(T1), PreorderIterator(T2)]

    until (cursor = iterator.next!).done
      tree-node = cursor.value

      children-count = children-count-of tree-node
      outdegree.set tree-node, children-count
      children.set tree-node, children-count

      if children-count is 0
        queue.push tree-node

        leaf-label = label-of tree-node

        # Only add-node once for each leaf-label
        if label-to-graph-node[leaf-label] is undefined
          label-to-graph-node[leaf-label] = graph.add-node leaf-label

  # Calculates mapping between tree node to DAG node in a bottom-up fashion.
  # Populates TreeNode-to-DAGNode map (tdmap).
  #
  # (L15-49)
  #
  do
    # console.log '[valiente#compact] Q:', Q.map -> label-of it .replace /[\n|\r]/g, ''
    # console.log '[valiente#compact] G:', G._nodes.map -> "<#{it.label.replace(/[\n|\r]/g,'')} #{it.height} [#{it._child-idx}]>"

    # Pop a tree node to process from the queue.
    #
    tree-node = queue.shift!  # Variable `u` in the paper

    # If the current tree is a leaf, it already has a graph node mapped to it.
    # (L17-18)
    #
    if outdegree.get(tree-node) is 0
      tdmap.add tree-node, label-to-graph-node[label-of tree-node]

    # (L19-49)
    #
    else
      is-candidate-found = false  # Variable `found` in the paper

      # Finding a candidate graph node that maps to the current tree node
      # in all graph nodes that has the same tree height.
      # (L21-32)
      #
      iterator = graph.generate-reverse-iterator!
      until (cursor = iterator.next!).done
        candidate-graph-node = cursor.value

        if height.get(tree-node) isnt candidate-graph-node.height
          break

        if outdegree.get(tree-node) != candidate-graph-node.outdegree! or
           label-of(tree-node) != candidate-graph-node.label
          continue

        # Check if their children graph node match.
        #
        graph-children-of-tree-node = children-of tree-node .map -> tdmap.get-node-from it
        graph-children-of-graph-node = candidate-graph-node.children!

        if array-equal graph-children-of-tree-node, graph-children-of-graph-node
          tdmap.add tree-node, candidate-graph-node
          is-candidate-found = true
          break

      # Create a new graph node when there is no candidate graph node found
      #
      # (L33-41)
      #
      unless is-candidate-found
        label = label-of tree-node
        graph-node = graph.add-node label, height.get tree-node
        tdmap.add tree-node, graph-node

        # Connect with the children graph nodes
        #
        for child-tree-node in children-of tree-node
          graph-node.add-child tdmap.get-node-from child-tree-node

    # If all children of a parent node has already been processed,
    # put the parent node into the process queue
    #
    # (L43-48)
    #
    unless is-root tree-node
      tree-parent = parent-of tree-node

      unprocessed-child-count = children.get(tree-parent) - 1
      children.set tree-parent, unprocessed-child-count

      if unprocessed-child-count is 0
        queue.push tree-parent

  until queue.length is 0

# Use the computed TreeNode-DAGNode mapping to infer the TreeNode-TreeNode mapping
# from tree T1 to T2.
#
# Procedure "mapping(T1, T2, G, K, M)" in Valeiente's paper.
#
# Input T1, T2: tree.
# Input tdmap: TreeDAGMap instance. Argument `K` in the paper.
# Output ttmap : TreeTreeMap instance that maps the nodes between T1 and T2.
#                Argument `M` in the paper.
#
# Let (L##-##) denotes the line number of the pseudo-code of procedure mapping
# in diffX paper.
#
!function mapping T1, T2, tdmap, ttmap

  preorder = new WeakMap

  # Get the right most node in T2, and calculate the preorder of each node in T2
  var rightmost-in-t2
  t2-iterator = PreorderIterator T2
  t2-idx = 0
  until (cursor = t2-iterator.next!).done
    preorder.set cursor.value, t2-idx
    t2-idx += 1
    rightmost-in-t2 = cursor.value

  # Traverse T1 in level order to calculate ttmap (top-down)
  # (L3-20)
  #
  iterator = LevelOrderIterator T1
  until (cursor = iterator.next!).done
    tree-node = cursor.value                        # The tree node in T1 seeking for mapped node in T2. Variable `v` in paper
    graph-node = tdmap.get-node-from tree-node      # The mapped graph node from the tree node. Variable `K[v]` in paper

    if ttmap.get-node-from(tree-node) is undefined

      # Find the "left-most" unmatched tree node in all T2's tree nodes that
      # mapped to the identical graph node with the current tree node.
      #
      # (L5-12)
      #
      mapped-tree-node = rightmost-in-t2         # Variable `w` in paper
      is-found = false

      for candidate in tdmap.get-nodes-to(graph-node) when is-in-t2(candidate) # `candidate` is variable `u` in paper
        if ttmap.get-node-to(candidate) is undefined and preorder.get(candidate) < preorder.get(mapped-tree-node)
          mapped-tree-node = candidate
          is-found = true

      # If the unmatched tree node is found, match it and all its children with
      #
      # (L13-18)
      #
      if is-found
        t1-iterator = PreorderIterator tree-node
        t2-iterator = PreorderIterator mapped-tree-node

        until (cursor1 = t1-iterator.next!).done or (cursor2 = t2-iterator.next!).done
          ttmap.add cursor1.value, cursor2.value

  # Helper function to see if a tree node belongs to T2
  function is-in-t2 (node)
    node.owner-document == T2.owner-document


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
