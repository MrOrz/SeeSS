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
  (@old-tree, @new-tree) ->
    # TODO:
    # Performs diffX and store the reference of the new node into new node
    # for #to-old-node to access.
    #
    ...

  # The public API of DiffXMatcher to get the corresponding old node from the new.
  #
  to-old-node: (new-node) ->
    new-node._seess-mapped-node

module.exports = DiffXMatcher