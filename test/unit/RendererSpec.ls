require! {
  '../../src/livescript/components/PageData.ls'
  '../../src/livescript/components/Renderer.ls'
  '../../src/livescript/components/RenderGraph.ls'
  '../../src/livescript/components/SerializableEvent.ls'
}

(...) <-! describe \Renderer, _

describe '#constructor', (...) !->
  it 'generates iframe as specified in PageData', ->
    const html-string = '<html><head></head><body></body></html>'
    page-data = new PageData do
      html: html-string

    renderer = new Renderer(page-data)
    <- renderer.render document.body .then
    rendered-doc = renderer.iframe.content-window.document

    expect rendered-doc.compat-mode .to.be \CSS1Compat
    expect rendered-doc.document-element.outerHTML .to.eql html-string

  it 'waits for images to load in PageData', ->
    # A page that contains a image with dimension of 126x123
    const html-string = "<html><head></head><body><img src=\"/base/test/fixtures/w126h123.jpg#{cache-burst!}\"></body></html>"

    page-data = new PageData do
      html: html-string
      url: location.href

    renderer = new Renderer page-data

    <- renderer.render document.body .then
    expect renderer.iframe.content-window.document.query-selector('img').width .to.be 126

  it 'waits for stylesheets to load in PageData', ->
    # A CSS that set h1 font size to 2rem (16 * 2 px)
    const html-string = "<html><head><link href=\"/base/test/fixtures/renderer-load.css#{cache-burst!}\" rel=\"stylesheet\"></head><body><h1>Yo</h1></body></html>"

    page-data = new PageData do
      html: html-string
      url: location.href

    renderer = new Renderer page-data

    <- renderer.render document.body .then
    h1 = renderer.iframe.content-window.document.query-selector('h1')
    h1-style = renderer.iframe.content-window.get-computed-style h1
    expect h1-style.font-size .to.be '32px' # 2rem

  it 'creates initial page snapshot', ->
    # A page that contains a image with dimension of 126x123
    const html-string = '<html><head></head><body><div><h1>Hello World</h1></div></body></html>'

    page-data = new PageData do
      html: html-string
      doctype:
        public-id: ''
        system-id: ''

    renderer = new Renderer page-data

    <- renderer.render document.body .then
    # specs
    expect renderer.snapshot[1].elem.node-name .to.be 'H1'
    expect renderer.snapshot[0].rect .to.be.a \object
    expect renderer.snapshot[0].computed .to.be.a \string
    expect renderer.snapshot[0].before-elem .to.be ""
    expect renderer.snapshot[0].after-elem .to.be ""

describe '#applyCSS', (...) !->

  it 'returns a SerializablePageDiff instance which can 100% recover a simple original page'

  it 'distinguishes position change', ->
    const NEW_CSS = 'renderer-css-position-test.css'

    renderer = new Renderer(new PageData html: __html__['test/fixtures/renderer-test.html'], url: location.href)
    <- renderer.render document.body .then

    new-css = load-css renderer.iframe.content-window.document, NEW_CSS

    # Trigger CSS apply
    page-diff <- renderer.applyCSS new-css .then

    expect page-diff.diffs .to.have.length 1

    # Checking type, elem and the actual difference
    expect page-diff.diffs.0.type .to.be Renderer.ElementDifference.TYPE_MOD
    expect page-diff.query-diff-id(0).class-name .to.be 'position-test'
    expect page-diff.diffs.0.rect.top .to.eql before: 0, after: 10
    expect page-diff.diffs.0.rect.left .to.eql before: 0, after: 10

  it 'distinguishes computed style change', ->
    const NEW_CSS = 'renderer-css-color-test2.css'

    renderer = new Renderer(new PageData html: __html__['test/fixtures/renderer-css-color-test.html'], url: location.href)
    <- renderer.render document.body .then

    new-css = load-css renderer.iframe.content-window.document, NEW_CSS

    # Triger CSS apply
    page-diff <- renderer.applyCSS new-css .then

    # there should be only one ElementDifference that reports
    # the color of h1 changed from blue to red.

    expect page-diff.diffs .to.have.length 1
    expect page-diff.query-diff-id(0).node-name .to.be \H1
    expect page-diff.diffs.0.computed.color.before .to.be "rgb(0, 0, 255)"
    expect page-diff.diffs.0.computed.color.after .to.be "rgb(255, 0, 0)"

  it 'distinguishes pseudo-element change', ->
    const NEW_CSS = 'renderer-css-pseudoelem-test.css'

    renderer = new Renderer(new PageData html: __html__['test/fixtures/renderer-test.html'], url: location.href)
    <- renderer.render document.body .then

    new-css = load-css renderer.iframe.content-window.document, NEW_CSS

    # Trigger CSS apply
    page-diff <- renderer.applyCSS new-css .then

    expect page-diff.diffs .to.have.length 1
    expect page-diff.query-diff-id(0).class-name .to.be 'position-test'
    expect page-diff.diffs.0.before-elem.color .to.eql before: 'rgb(0, 0, 0)', after: 'rgb(255, 0, 0)'

  it 'works for multiple calls to #applyCSS', ->
    const CSS1 = 'renderer-css-position-test.css'
    const CSS2 = 'renderer-css-test.css' # Change back to css-test

    renderer = new Renderer(new PageData html: __html__['test/fixtures/renderer-test.html'], url: location.href)
    <- renderer.render document.body .then

    new-css = load-css renderer.iframe.content-window.document, CSS1

    # Trigger CSS apply
    <- renderer.applyCSS new-css .then

    # CSS1 is already tested in another test suite. Go change CSS to CSS2.
    new-css = load-css renderer.iframe.content-window.document, CSS2, CSS1

    page-diff <- renderer.applyCSS new-css .then

    expect page-diff.diffs .to.have.length 1

    # Check if the difference equals the change caused by
    # CSS2 --> CSS1.
    expect page-diff.diffs.0.type .to.be Renderer.ElementDifference.TYPE_MOD
    expect page-diff.query-diff-id(0).class-name .to.be 'position-test'
    expect page-diff.diffs.0.rect.top .to.eql before: 10, after: 0
    expect page-diff.diffs.0.rect.left .to.eql before: 10, after: 0

  it 'do not output false alarm when there is no visual difference', ->
    const NEW_CSS = 'renderer-css-invariant-test.css'

    renderer = new Renderer(new PageData html: __html__['test/fixtures/renderer-test.html'], url: location.href)
    <- renderer.render document.body .then

    new-css = load-css renderer.iframe.content-window.document, NEW_CSS

    # Trigger CSS apply
    page-diff <- renderer.applyCSS new-css .then

    expect page-diff .to.be null

  # TODO
  it.skip 'do not output false alarm when z-index change is introduced by position change', ->
    const NEW_CSS = 'renderer-css-invariant-zindex-test.css'

    renderer = new Renderer(new PageData html: __html__['test/fixtures/renderer-css-invariant-zindex-test.html'], url: location.href)
    <- renderer.render document.body .then

    new-css = load-css renderer.iframe.content-window.document, NEW_CSS

    # Trigger CSS apply
    page-diff <- renderer.applyCSS new-css .then

    expect page-diff .to.be null



  function load-css doc, new-filename, old-filename = \PLACEHOLDER
    # Hack: Change the CSS filename inside renderer iframe to simulate CSS file change
    link = doc.get-element-by-id \css-target
    link.href .= replace old-filename, new-filename

    return link.href


describe '#applyHTML', (...) !->
  it 'updates source iframe and detects diff change on content text change', ->
    ({page-diff, renderer}) <- feed-test-file-to-source-renderer 'renderer-html-text-test' .then

    expect renderer.iframe.content-window.document.query-selector('#target').text-content .to.be 'Yo!'

    expect page-diff .to.be.ok!
    expect page-diff.diffs .to.have.length 1
    expect page-diff.query-diff-id(0).id .to.be \target

  it 'deals with attribute change on source iframe', ->
    ({page-diff, renderer}) <- feed-test-file-to-source-renderer 'renderer-html-attr-test' .then

    expect page-diff .to.be.ok!
    expect page-diff.diffs .to.have.length 1
    expect page-diff.diffs.0.type .to.be Renderer.ElementDifference.TYPE_MOD
    expect page-diff.diffs.0.computed .to.eql do
      'border-bottom-color':
        before: "rgb(255, 0, 0)"
        after: "rgb(0, 0, 255)"

    expect page-diff.query-diff-id(0).class-name .to.be \blue

  it 'deals with element addition', ->
    ({page-diff, renderer}) <- feed-test-file-to-source-renderer 'renderer-html-add-test' .then

    expect page-diff .to.be.ok!
    expect page-diff.diffs .to.have.length 2

    expect page-diff.diffs.0.type .to.be Renderer.ElementDifference.TYPE_ADDED
    expect page-diff.query-diff-id(0).class-name .to.be \added

    expect page-diff.diffs.1.type .to.be Renderer.ElementDifference.TYPE_MOD
    expect page-diff.diffs.1.rect .to.eql do
      top:
        before: 0
        after: 16
      bottom:
        before: 16
        after: 32


  it 'deals with element removal', ->
    ({page-diff, renderer}) <- feed-test-file-to-source-renderer 'renderer-html-remove-test' .then

    expect page-diff .to.be.ok!
    expect page-diff.diffs .to.have.length 4

    container = page-diff.query-diff-id(0)
    expect container.node-name .to.be \DIV

    expect page-diff.diffs.3.type .to.be Renderer.ElementDifference.TYPE_REMOVED

    # In this test case, the removed element's ID is attached to its parent,
    # which happens to be the the container of all buttons
    #
    removed-element-parent = page-diff.query-diff-id 3
    expect removed-element-parent .to.be container

  it 'deals with multi-layer structure removal', ->
    ({page-diff, renderer}) <- feed-test-file-to-source-renderer 'renderer-html-remove-test2' .then

    expect page-diff .to.be.ok!
    expect page-diff.diffs .to.have.length 3

    for i from 0 to 2
      container = page-diff.query-diff-id(i)
      expect container.node-name .to.be \BODY
      expect page-diff.diffs[i].type .to.be Renderer.ElementDifference.TYPE_REMOVED


  it 'executes event stream and detects identical states', ->

    # Assume a renderer rendering a page that is 2 clicks away from source.
    #
    # renderer-html-click-test-src --- 2 clicks --> renderer-html-click-test-state1
    #
    renderer = new Renderer (new PageData html: __html__['test/fixtures/renderer-html-click-test-state1.html'])

    <- renderer.render document.body .then

    edges =
      new RenderGraph.Edge null, new SerializableEvent {constructorName: 'MouseEvent', target: '/html/body/ul/*[1]', type: 'click', which: 1, bubbles: true, cancelable: true}
      new RenderGraph.Edge null, new SerializableEvent {constructorName: 'MouseEvent', target: '/html/body/ul/*[2]', type: 'click', which: 1, bubbles: true, cancelable: true}

    # Use http://127.0.0.1 instead of http://localhost to simulate cross-origin scenario
    #
    ({page-diff, mapping}) <- renderer.applyHTML "http://127.0.0.1:#{location.port}/base/test/served/renderer-html-click-test-src.html", Promise.resolve(edges) .then

    expect page-diff .to.be null

  it 'rejects promise when events could not be replayed'

  function feed-test-file-to-source-renderer testfile
    renderer = new Renderer(new PageData html: __html__["test/fixtures/#{testfile}-before.html"])
    <- renderer.render document.body .then

    ({page-diff, mapping}) <- renderer.applyHTML "#{location.origin}/base/test/served/#{testfile}-after.html", Promise.resolve([]) .then

    return {page-diff, mapping, renderer}

function cache-burst
  "?burst=#{('' + Math.random!).slice 2}"
