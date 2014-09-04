require! {
  algo: '../../src/livescript/components/MappingAlgorithm.ls'
}

(...) <-! describe \MappingAlgorithm

describe \TreeTreeMap, (...) !->

  var ttmap

  # The two node "trees" we used as test data
  t1 = [document.create-element 'div' for i to 10]
  t2 = [document.create-element 'div' for i to 11]

  before-each ->
    ttmap := new algo.TreeTreeMap

    # t1[0] --> t2[0], ..., t1[9] --> t2[9]
    # t1[10], t2[10], t2[11] are not mapped deliberately.
    #
    for i to 9
      ttmap.add t1[i], t2[i]

  describe '#has', (...) !->
    it 'correctly returns whether a node is in set', ->
      expect ttmap.has t1.0, t2.0 .to.be true
      expect ttmap.has t2.0, t1.0 .to.be false # directional
      expect ttmap.has t1.9, t2.9 .to.be true
      expect ttmap.has t1.0, t2.9 .to.be false # mis-map
      expect ttmap.has t1.10, t2.10 .to.be false # non-existence mapping

      # Single x or y
      expect ttmap.has t1.3 .to.be true
      expect ttmap.has t1.10 .to.be false
      expect ttmap.has null, t2.11 .to.be false

    it 'throws error if neither x nor y is specified', ->
      expect (-> ttmap.has!) .to.throw-error!
      expect (-> ttmap.has t1.100, t2.100) .to.throw-error!

  describe '#merge', (...) !->
    it 'merges two TreeTreeMaps', ->
      ttmap2 = new algo.TreeTreeMap
      ttmap2.add t1.10, t2.10

      ttmap.merge ttmap2

      expect ttmap.has t1.10, t2.10 .to.be true
      expect ttmap.has t2.10, t1.10 .to.be false
      expect ttmap.has null,  t2.10 .to.be true
      expect ttmap.has t1.10, null  .to.be true
      expect ttmap.has null,  t2.11 .to.be false

  describe '#get-node-*', (...) !->
    it 'returns the mapped nodes correctly', ->
      expect ttmap.get-node-to t2.7 .to.be t1.7
      expect ttmap.get-node-from t2.7 .to.be undefined # Mis-use of get-node-from should return undefined
      expect ttmap.get-node-from t1.7 .to.be t2.7
      expect ttmap.get-node-from t1.10 .to.be undefined


describe \#diffX, (...) !->

  # Sharted DOMParser instance
  parser = new DOMParser

  # The two trees as test data.
  var t1, t2

  # t1 and t2 resets for each test, so that each test gets a fresh copy
  #
  before-each ->
    simple-html-str = __html__['test/fixtures/diffx-simple.html']
    t1 := parser.parse-from-string simple-html-str, 'text/html'
    t2 := parser.parse-from-string simple-html-str, 'text/html'

  it 'maps two identical trees', ->
    ttmap = algo.diffX t1.body, t2.body

    t1-walker = t1.create-tree-walker t1.body, NodeFilter.SHOW_ELEMENT .|. NodeFilter.SHOW_TEXT
    t2-walker = t2.create-tree-walker t2.body, NodeFilter.SHOW_ELEMENT .|. NodeFilter.SHOW_TEXT

    do
      expect-match ttmap, t1-walker.current-node, t2-walker.current-node
    while t1-walker.next-node! && t2-walker.next-node!

  it 'maps trees with text node change', ->
    # Change Inline Text #2
    text = Array::filter.call(t2.body.child-nodes, -> it.node-type is Node.TEXT_NODE and it.node-value.index-of 'Inline Text #2' != -1 ).0
    text.node-value = 'Inline Text #2 改'

    ttmap = algo.diffX t1.body, t2.body

    # Even if the text nodes changed, all elements should still match.
    t1-walker = t1.create-tree-walker t1.body, NodeFilter.SHOW_ELEMENT
    t2-walker = t2.create-tree-walker t2.body, NodeFilter.SHOW_ELEMENT

    do
      expect-match ttmap, t1-walker.current-node, t2-walker.current-node
    while t1-walker.next-node! && t2-walker.next-node!


  it 'maps trees with attribute node change', ->
    divs = t2.query-selector-all 'body>div'

    # Modify the class of the first div
    divs.0.class-list.add 'changed'
    # Also add exactly the same class to the 2nd "Deliberately Similar" <div>
    divs.2.class-list.add 'changed'

    ttmap = algo.diffX t1.body, t2.body

    # Even if the attributes changed, all elements should still match.
    t1-walker = t1.create-tree-walker t1.body, NodeFilter.SHOW_ELEMENT
    t2-walker = t2.create-tree-walker t2.body, NodeFilter.SHOW_ELEMENT

    do
      expect-match ttmap, t1-walker.current-node, t2-walker.current-node
    while t1-walker.next-node! && t2-walker.next-node!

  #
  # TODO:
  #
  # The _match-fragment in diffX paper always matches #span2 mistakenly
  # when doing <body>'s mapping in _mapping function,
  # because the for loop in _match-fragment is very sensitive to order of elements.
  #
  it.skip 'maps trees with two element nodes swapped', ->

    # Move #span2 in front of #span1
    t2.body.insert-before t2.get-element-by-id(\span2), t2.get-element-by-id(\span1)

    # Check if the node are really swapped in t2 by checking the first span in t2
    # and span1 should be the last child in body
    expect t2.query-selector(\span).id .to.be \span2
    expect t2.query-selector('#span1:last-child') .not.to.be null

    ttmap = algo.diffX t1.body, t2.body

    # Expect the first found span in both trees are not matched
    expect-mismatch ttmap, t1.query-selector(\span), t1.query-selector(\span)

    # Check if span1 and span2 are correctly mapped
    expect-match ttmap, t1.get-element-by-id(\span1), t2.get-element-by-id(\span1)
    expect-match ttmap, t1.get-element-by-id(\span2), t2.get-element-by-id(\span2)

  #
  # TODO:
  #
  # The _match-fragment in diffX paper always matches #span2 mistakenly
  # when doing <body>'s mapping in _mapping function,
  # because the for loop in _match-fragment is very sensitive to order of elements.
  #
  it.skip 'maps trees with hierarchical deepened subtrees', ->
    t1-divs = t1.query-selector-all \div
    t2-divs = t2.query-selector-all \div

    # Create a new div that collects all div in body.
    new-div = t2.create-element \div
    t2.body.insert-before new-div, t2-divs[0]

    for div in t2-divs
      new-div.insert-before div

    # Check the nested div structure
    expect t2.query-selector-all 'div>div' .to.have.length 3

    ttmap = algo.diffX t1.body, t2.body

    # The divs between of two trees should still be matched
    for t1-div, idx in t1-divs
      expect-match ttmap, t1-div, t2-divs[idx]

    # The #span1 should still be matched
    expect-match ttmap, t1.get-element-by-id(\span1), t2.get-element-by-id(\span1)


  it 'maps trees with subtree addition', ->
    t1-divs = t1.query-selector-all \div
    t2-divs = t2.query-selector-all \div

    # Insert a <section> into the first <div> in t2
    #
    new-tree = parser.parse-from-string '<section>Inline Text <em>#3</em></section>', 'text/html'
    t2.query-selector \div .insert-before new-tree.query-selector(\section)

    ttmap = algo.diffX t1.body, t2.body

    # The divs between of two trees should still be matched
    for t1-div, idx in t1-divs
      expect-match ttmap, t1-div, t2-divs[idx]

    # The #span1 should still be matched
    expect-match ttmap, t1.get-element-by-id(\span1), t2.get-element-by-id(\span1)


  it 'maps trees with subtree deletion', ->
    # Remove the first <div> in t2
    t2.body.remove-child t2.query-selector \div

    ttmap = algo.diffX t1.body, t2.body

    # The #span1 should still be matched
    expect-match ttmap, t1.get-element-by-id(\span1), t2.get-element-by-id(\span1)


  it 'processes the example provided in diffX paper', ->
    scifi1 = parser.parse-from-string __html__['test/fixtures/diffx-scifi1'], 'application/xml'
    scifi2 = parser.parse-from-string __html__['test/fixtures/diffx-scifi2'], 'application/xml'

    ttmap = algo.diffX scifi1.document-element, scifi2.document-element

    # Match <scifi-store>, <books>, .... between scifi1 and scifi2.
    #
    # It is the subset of matches specified in the diffX paper.
    #
    for selector in <[scifi-store books book title arthors price movies movie]>
      elems1 = scifi1.query-selector-all selector
      elems2 = scifi2.query-selector-all selector
      for elem, i in elems1
        expect-match ttmap, elem, elems2[i]

  # Expects the ttmap to match t1-node to t2-node.
  # Tests get-node-from and get-node-to together.
  #
  function expect-match ttmap, t1-node, t2-node
    expect ttmap.get-node-from(t1-node) .to.be t2-node
    expect ttmap.get-node-to(t2-node) .to.be t1-node

  # Expects the ttmap not to match t1-node to t2-node.
  # Tests get-node-from and get-node-to together.
  #
  function expect-mismatch ttmap, t1-node, t2-node
    expect ttmap.get-node-from(t1-node) .not.to.be t2-node
    expect ttmap.get-node-to(t2-node) .not.to.be t1-node

describe \#valiente, (...) !->

  # Sharted DOMParser instance
  parser = new DOMParser
  var t1, t2

  # Helper function that returns the first element matching given xpath in specific document.
  # It is designed to be used like document.querySelector().
  #
  # https://developer.mozilla.org/en-US/docs/Web/API/document.evaluate
  #
  function query-path doc, xpath
    doc.evaluate xpath, doc, null, XPathResult.ANY_TYPE, null .iterate-next!

  # Expects the ttmap to match xpath1 in t1 and xpath2 in t2
  #
  function expect-match ttmap, xpath1, xpath2
    expect ttmap.get-node-from(t1 query-path xpath1) .to.be (t2 query-path xpath2)

  it 'matches specified nodes in Figure 3 in Valiente paper', ->
    t1 := parser.parse-from-string __html__['test/fixtures/valiente-fig3-t1'], 'application/xml'
    t2 := parser.parse-from-string __html__['test/fixtures/valiente-fig3-t2'], 'application/xml'

    ttmap = algo.valiente t1.document-element, t2.document-element
    expect-match ttmap, '/r/a/a',    '/r/a'
    expect-match ttmap, '/r/a/a/a',  '/r/a/a'
    expect-match ttmap, '/r/e',      '/r/e/e'
    expect-match ttmap, '/r/e/e',    '/r/e/e/e'
    expect-match ttmap, '/r/e/e/e',  '/r/e/e/e/e'
    expect-match ttmap, '/r/e/c',    '/r/e/e/c'

  it 'matches specified nodes in Figure 8 in Valiente paper', ->
    t1 := parser.parse-from-string __html__['test/fixtures/valiente-fig3-t1'], 'application/xml'
    t2 := parser.parse-from-string __html__['test/fixtures/valiente-fig3-t2'], 'application/xml'

    ttmap = algo.valiente t1.document-element, t2.document-element

    expect-match ttmap, '/n6/n3',      '//n7/n3'
    expect-match ttmap, '//n3/n2/n1',  '//n3/n2/n1'
    expect-match ttmap, '//n4/n2[1]/n1',  '//n7/n2/n1'
    expect-match ttmap, '//n4/n2[2]/n1',  '//n5/n2/n1'
