require! {
  '../../src/livescript/components/PageData.ls'
}

(...) <-! describe \PageData, _

describe '#constructor', (...) !->

  it 'takes care of <href>\'s links', ->
    input-html = """
      <html>
        Fake link href should not be altered: &lt;link href="intact.css"&gt;
        <link href="../relative.css" ref="stylesheets">
        <link href="http://somewhere.else/absolute.css" ref="stylesheets">
        <link href="//no-protocol.com/la.css" ref="stylesheets">
        <link
          href="/root.css"
          ref="stylesheets"
        >
      </html>
    """

    expected = """
      <html>
        Fake link href should not be altered: &lt;link href="intact.css"&gt;
        <link href="http://vuse.tw/channels/1/relative.css" ref="stylesheets">
        <link href="http://somewhere.else/absolute.css" ref="stylesheets">
        <link href="http://no-protocol.com/la.css" ref="stylesheets">
        <link
          href="http://vuse.tw/root.css"
          ref="stylesheets"
        >
      </html>
    """

    output = new PageData html: input-html, url: 'http://vuse.tw/channels/1/users/2?tag=123#hash'

    expect input-html .to.eql expected

  it 'takes care of url() in <style> and style attributes', ->
    input-html = """
      <html>
        style="url('not-modified.jpg')"
        <style>
          .a {
            background: url(a.jpg) #333;
            background: url("b.jpg") #333;
          }
          @font-face{
            src: url('font.eot?') format('eot'),
                 url('font.woff') format('woff'),
                 url('font.ttf') format('truetype');
          }
        </style>
        <div style="background: url('mi.jpg')" ng-style="{font: 'not affected'}"></div>
      </html>
    """

    expected = """
      <html>
        style="url('not-modified.jpg')"
        <style>
          .a {
            background: url(http://vuse.tw/channels/1/users/a.jpg) #333;
            background: url("http://vuse.tw/channels/1/users/b.jpg") #333;
          }
          @font-face{
            src: url('http://vuse.tw/channels/1/users/font.eot?') format('eot'),
                 url('http://vuse.tw/channels/1/users/font.woff') format('woff'),
                 url('http://vuse.tw/channels/1/users/font.ttf') format('truetype');
          }
        </style>
        <div style="background: url('http://vuse.tw/channels/1/users/mi.jpg')" ng-style="{font: 'not affected'}"></div>
      </html>
    """

    expect input-html .to.eql expected


  it 'strips all <script> tags', ->
    input-html = """
      <html>script &lt;
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
      </html>
    """

    expected = """
      <html>script &lt;
        script&gt;
      </html>
    """

    output = new PageData html: input-html, url: 'http://google.com'

    expect output.html .to.eql expected