# Difference between old element and new element
#
# The structure of ElementDifference object is the same as ElementSnapshot instances,
# except that each property value is replaced by {before: <val-before>, after: <val-after>},
# and has @type attributes in addition.
#
# However, if @type is not TYPE_MOD, the property value will be a scalar term,
# since there is no "before" or "after" when adding or removing elements.
#
# If type is TYPE_REMOVED, @before-html stores the innerHTML of the parent of the removed node,
# before its removal.
#
class ElementDifference
  const @TYPE_MOD = 0
  const @TYPE_ADDED = 1
  const @TYPE_REMOVED = 2

  ( diff-or-snapshot, @type = @@TYPE_MOD, @before-html ) ->
    @ <<< diff-or-snapshot
    @elem = undefined if @elem # Remove @elem if from snapshot

    if @bounding-box is undefined # If no bounding box, use @rect as default
      @bounding-box =
        left: diff-or-snapshot.rect.left
        right: diff-or-snapshot.rect.right
        top: diff-or-snapshot.rect.top
        bottom: diff-or-snapshot.rect.bottom

module.exports = ElementDifference