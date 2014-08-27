require! {
  '../../src/livescript/components/PageData.ls'
  '../../src/livescript/components/Renderer.ls'
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

  it 'distinguishes position change', ->
    const NEW_CSS = 'renderer-css-position-test.css'

    renderer = new Renderer(new PageData html: __html__['test/fixtures/renderer-test.html'], url: location.href)
    <- renderer.render document.body .then

    new-css = load-css renderer.iframe.content-window.document, NEW_CSS

    # Trigger CSS apply
    diff <- renderer.applyCSS new-css .then

    expect diff.length .to.be 1

    # Checking type, elem and the actual difference
    expect diff.0.type .to.be Renderer.ElementDifference.TYPE_MOD
    expect diff.0.elem.class-name .to.be 'position-test'
    expect diff.0.rect.top .to.eql before: 0, after: 10
    expect diff.0.rect.left .to.eql before: 0, after: 10

  it 'distinguishes computed style change', ->
    const NEW_CSS = 'renderer-css-color-test2.css'

    renderer = new Renderer(new PageData html: __html__['test/fixtures/renderer-css-color-test.html'], url: location.href)
    <- renderer.render document.body .then

    new-css = load-css renderer.iframe.content-window.document, NEW_CSS

    # Triger CSS apply
    diff <- renderer.applyCSS new-css .then

    # there should be only one ElementDifference that reports
    # the color of h1 changed from blue to red.

    expect diff.length .to.be 1
    expect diff.0.elem.node-name .to.be \H1
    expect diff.0.computed.color.before .to.be "rgb(0, 0, 255)"
    expect diff.0.computed.color.after .to.be "rgb(255, 0, 0)"

  it 'distinguishes pseudo-element change', ->
    const NEW_CSS = 'renderer-css-pseudoelem-test.css'

    renderer = new Renderer(new PageData html: __html__['test/fixtures/renderer-test.html'], url: location.href)
    <- renderer.render document.body .then

    new-css = load-css renderer.iframe.content-window.document, NEW_CSS

    # Trigger CSS apply
    diff <- renderer.applyCSS new-css .then

    expect diff.length .to.be 1
    expect diff.0.elem.class-name .to.be 'position-test'
    expect diff.0.before-elem.color .to.eql before: 'rgb(0, 0, 0)', after: 'rgb(255, 0, 0)'

  it 'works for multiple calls to #applyCSS', ->
    const CSS1 = 'renderer-css-position-test.css'
    const CSS2 = 'renderer-css-test.css' # Change back to css-test

    renderer = new Renderer(new PageData html: __html__['test/fixtures/renderer-test.html'], url: location.href)
    <- renderer.render document.body .then

    new-css = load-css renderer.iframe.content-window.document, CSS1

    # Trigger CSS apply
    diff <- renderer.applyCSS new-css .then

    # CSS1 is already tested in another test suite. Go change CSS to CSS2.
    new-css = load-css renderer.iframe.content-window.document, CSS2, CSS1

    diff <- renderer.applyCSS new-css .then

    expect diff.length .to.be 1

    # Check if the difference equals the change caused by
    # CSS2 --> CSS1.
    expect diff.0.type .to.be Renderer.ElementDifference.TYPE_MOD
    expect diff.0.elem.class-name .to.be 'position-test'
    expect diff.0.rect.top .to.eql before: 10, after: 0
    expect diff.0.rect.left .to.eql before: 10, after: 0

  it 'do not output false alarm when there is no visual difference', ->
    const NEW_CSS = 'renderer-css-invariant-test.css'

    renderer = new Renderer(new PageData html: __html__['test/fixtures/renderer-test.html'], url: location.href)
    <- renderer.render document.body .then

    new-css = load-css renderer.iframe.content-window.document, NEW_CSS

    # Trigger CSS apply
    diff <- renderer.applyCSS new-css .then

    expect diff.length .to.be 0

  # TODO
  it.skip 'do not output false alarm when z-index change is introduced by position change', ->
    const NEW_CSS = 'renderer-css-invariant-zindex-test.css'

    renderer = new Renderer(new PageData html: __html__['test/fixtures/renderer-css-invariant-zindex-test.html'], url: location.href)
    <- renderer.render document.body .then

    new-css = load-css renderer.iframe.content-window.document, NEW_CSS

    # Trigger CSS apply
    diff <- renderer.applyCSS new-css .then

    expect diff.length .to.be 0



  function load-css doc, new-filename, old-filename = \PLACEHOLDER
    # Hack: Change the CSS filename inside renderer iframe to simulate CSS file change
    link = doc.get-element-by-id \css-target
    link.href .= replace old-filename, new-filename

    return link.href


describe '#applyHTML', (...) !->
  it 'updates iframe on content text change'

  it 'detects node change and generates correct style diff'

  it 'detects new elements and generates correct style diff'

  it 'detects element removal and generates correct style diff'

  it 'detects wrapping new DOM element and generates correct style diff'


function cache-burst
  "?burst=#{('' + Math.random!).slice 2}"
