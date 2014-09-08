require! {
  '../../src/livescript/components/SerializablePageDiff.ls'
}

(...) <-! describe \SerializablePageDiff, _

describe '#constructor', (...) !->

  it 'throws error when neither dom nor html is specified', ->
    expect (-> new SerializablePageDiff diffs: <[foo]>) .to.throw-error!

  it 'throws error when there is no diff', ->
    expect (-> new SerializablePageDiff html: '<body></body>') .to.throw-error!

  it 'does not populate @_dom when not needed', ->
    page-diff = new SerializablePageDiff(html: '<body></body>', diffs: <[foo]>)
    expect page-diff._dom .to.be undefined

  it "populates @html with provided DOM", ->

    # case #1: Deep-copy of the current body element
    #
    body-elem = document.body.clone-node true
    page-diff = new SerializablePageDiff(dom: body-elem, diffs: <[foo]>)
    expect page-diff.html .to.eql body-elem.outerHTML

    # case #2: Body element from string
    #
    parser = new DOMParser
    const body-string = '<body class="a">Hello <span>world</span></body>'
    body-elem = parser.parse-from-string body-string, 'text/html' .body
    page-diff = new SerializablePageDiff(dom: body-elem, diffs: <[foo]>)
    expect page-diff.html .to.eql body-string


describe '#toJSON', (...) !->
  it 'should be serializable', ->
    page-diff = new SerializablePageDiff html: '<body></body>', diffs: <[foo]>
    expect JSON.stringify(page-diff) .to.be.a \string

  it 'should be able to restore to a full-feature SerializablePageDiff instance', ->
    page-diff = new SerializablePageDiff html: '<body><span>text1</span>text2</body>', diffs: <[foo]>

    restored = JSON.parse JSON.stringify page-diff
    restored-page-diff = new SerializablePageDiff restored

    # Invoke @dom() on restored-page-diff
    expect restored-page-diff.dom!child-nodes.length .to.be page-diff.dom!child-nodes.length

describe '#query-diff-id', (...) !->

  it 'returns the element with corresponding diff-id', ->
    page-diff = new SerializablePageDiff do
      html: "<body><span id=\"target\" #{SerializablePageDiff.DIFF_ID_ATTR}=\"0\">text1</span>text2</body>"
      diffs: <[foo]>

    expect page-diff.query-diff-id(0).id .to.be \target
