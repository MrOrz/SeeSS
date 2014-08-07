require! {
  '../../src/livescript/components/PageData.ls'
}

(...) <-! describe \PageData, _

describe '#constructor', (...) !->

  it 'takes care of link[href], iframe[src] and img[src]', ->
    input-html = """
      <html><head>
        <link href="../relative.css" ref="stylesheets">
        <link href="http://somewhere.else/absolute.css" ref="stylesheets">
        <link href="//no-protocol.com/la.css" ref="stylesheets">
        <link
          href="/root.css"
          ref="stylesheets"
        >
      </head>
      <body>
        Fake link href should not be altered: &lt;link href="intact.css"&gt;
        <img src="some-img?params">
        <iframe src="some-html?params\#hash"></iframe>
      </body></html>
    """

    expected = """
      <html><head>
        <link href="http://vuse.tw/channels/1/relative.css" ref="stylesheets">
        <link href="http://somewhere.else/absolute.css" ref="stylesheets">
        <link href="http://no-protocol.com/la.css" ref="stylesheets">
        <link href="http://vuse.tw/root.css" ref="stylesheets">
      </head>
      <body>
        Fake link href should not be altered: &lt;link href="intact.css"&gt;
        <img src="http://vuse.tw/channels/1/users/some-img?params">
        <iframe src="http://vuse.tw/channels/1/users/some-html?params\#hash"></iframe>
      </body></html>
    """

    output = new PageData html: input-html, url: 'http://vuse.tw/channels/1/users/2?tag=123#hash'

    expect output.dom.documentElement.outerHTML .to.eql expected

  it 'takes care of url() in <style> and style attributes', ->
    input-html = """
      <html><head></head><body>
        style="url('not-in-style-thus-not-modified.jpg')"
        <style>
          .a {
            background: url(a.jpg) #333;
            background: url("b.jpg") #333;
          }
        </style>
        <style>
          @font-face{
            src: url('font.eot?') format('eot'),
                 url('font.woff') format('woff'),
                 url('font.ttf') format('truetype');
          }
        </style>
        <div style="background: url('mi.jpg')" ng-style="{font: url('not-affected')}"></div>
      </body></html>
    """

    expected = """
      <html><head></head><body>
        style="url('not-in-style-thus-not-modified.jpg')"
        <style>
          .a {
            background: url('http://vuse.tw/channels/1/users/a.jpg') #333;
            background: url('http://vuse.tw/channels/1/users/b.jpg') #333;
          }
        </style>
        <style>
          @font-face{
            src: url('http://vuse.tw/channels/1/users/font.eot?') format('eot'),
                 url('http://vuse.tw/channels/1/users/font.woff') format('woff'),
                 url('http://vuse.tw/channels/1/users/font.ttf') format('truetype');
          }
        </style>
        <div style="background: url('http://vuse.tw/channels/1/users/mi.jpg')" ng-style="{font: url('not-affected')}"></div>
      </body></html>
    """

    output = new PageData html: input-html, url: 'http://vuse.tw/channels/1/users/2?tag=123#hash'

    expect output.dom.documentElement.outerHTML .to.eql expected


  it 'strips all <script> tags', ->
    input-html = """
      <html><head></head><body>script &lt;
        script&gt;
        <script type="text/javascript">
          var a = 42;
        </script>
        <script
          type="text/templates">
          var a = 42;
        </script>
        <script src="lala">
          blah
        </script>
        <script>
          blahblah
        </script>
      </body></html>
    """

    expected = """
      <html><head></head><body>script &lt;
        script&gt;
        
        
        
        
      </body></html>
    """

    output = new PageData html: input-html, url: 'http://google.com'

    expect output.dom.documentElement.outerHTML .to.eql expected