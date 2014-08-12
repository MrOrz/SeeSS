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
      doctype:
        public-id: ''
        system-id: ''

    renderer = new Renderer(page-data)
    <- renderer.render document.body .then
    rendered-doc = renderer.iframe.content-window.document

    expect rendered-doc.compat-mode .to.be \CSS1Compat
    expect rendered-doc.document-element.outerHTML .to.eql html-string

  it 'waits for assets to load in PageData', ->
    # A page that contains a image with dimension of 126x123
    const html-string = '<html><head></head><body><img src="http://placekitten.com/126/123"></body></html>'

    page-data = new PageData do
      html: html-string
      doctype:
        public-id: ''
        system-id: ''
      url: 'http://google.com'

    renderer = new Renderer page-data

    <- renderer.render document.body .then
    expect renderer.iframe.content-window.document.query-selector('img').width .to.be 126

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
    expect renderer.snapshot[0].computed .to.be.a \object

describe '#applyCSS', (...) !->
  it 'distinguishes position change', ->
    const NEW_CSS = 'renderer-css-position-test.css'

    renderer = new Renderer(new PageData html: __html__['test/fixtures/renderer-test.html'], url: location.href)
    <- renderer.render document.body .then

    # Hack: Change the CSS filename inside renderer iframe to simulate CSS file change
    link = renderer.iframe.content-window.document.get-element-by-id \css-target
    link.href .= replace 'renderer-css-test.css', NEW_CSS

    # Trigger CSS apply
    diff <- renderer.applyCSS link.href .then

    expect diff.length .to.be 1
    expect diff.0.elem.class-name .to.be 'position-test'
    expect diff.0.rect.top .to.eql before: 0, after: 10
    expect diff.0.rect.left .to.eql before: 0, after: 10


  it 'distinguishes pseudo-element change', ->
    ...

  it 'works for multiple calls to #applyCSS', ->
    ...


describe '#applyHTML', (...) !->
  it 'refreshes on attribute change', ->
    ...

  it 'detects new child element and generates correct style diff', ->
    ...

  it 'detects wrapping new DOM element and generates correct style diff', ->
    ...
