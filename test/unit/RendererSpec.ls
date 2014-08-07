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