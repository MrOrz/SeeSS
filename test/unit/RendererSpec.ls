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
    renderer.render document.body .then ->
      rendered-doc = renderer.iframe.content-window.document

      expect rendered-doc.doctype.public-id .to.eql ''
      expect rendered-doc.doctype.system-id .to.eql ''
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

    renderer.render document.body .then ->
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

    renderer.render document.body .then ->
      # specs
      expect renderer.snapshot[1].elem.node-name .to.be 'H1'
      expect renderer.snapshot[0].rect .to.be.a \object
      expect renderer.snapshot[0].computed .to.be.a \object
