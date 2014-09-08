require! {
  '../../src/livescript/components/XPathUtil.ls'.queryXPath
  '../../src/livescript/components/XPathUtil.ls'.queryXPathAll
  '../../src/livescript/components/XPathUtil.ls'.generateXPath
}


(...) <-! describe \XPathUtil

parser = new DOMParser
doc = parser.parse-from-string "
  <a>
    <b>
      <c />
      <c />
      <c />
    </b>
  </a>
", 'application/xml'

describe '#query-x-path', (...) !->

  <-! it 'returns correct element'
  first-c = doc.query-selector \c

  expect (doc `query-x-path` '/a/b/c') .to.be first-c

describe '#query-x-path-all', (...) !->
  <-! it 'returns correct array of elements'
  all-cs = Array::slice.call doc.query-selector-all \c

  expect (doc `query-x-path-all` '/a/b/c') .to.eql all-cs

describe '#generate-x-path', (...) !->
  it 'processes XML trees', ->
    c = doc.query-selector 'c:nth-child(2)'
    x-path = generate-x-path c

    expect x-path .to.be '/*[1]/*[1]/*[2]'
    expect (doc `query-x-path` x-path) .to.be c

  it 'processes HTML trees and prefix xpath with <body>', (...) !->
    htmldoc = parser.parse-from-string "
      <div>
        <h1>Header</h1>
        <p>paragraph 1</p>
        <p>paragraph 2</p>
      </div>
    ", 'text/html'

    p = htmldoc.query-selector 'p:nth-child(3)'
    x-path = generate-x-path p

    expect x-path .to.be '/html/body/*[1]/*[3]'
    expect (htmldoc `query-x-path` x-path) .to.be p

  it 'should not be affected by text nodes', (...) !->
    htmldoc = parser.parse-from-string """
      <html><head><style>
        .red { color: red; }
      </style>

      </head><body><ul class="red">
        <li class="add-button">Add item</li>
      </ul>

      </body></html>
    """, 'text/html'

    add-button = htmldoc.query-selector '.add-button'
    x-path = generate-x-path add-button

    expect x-path .to.be '/html/body/*[1]/*[1]'
    expect (htmldoc `query-x-path` x-path) .to.be add-button
