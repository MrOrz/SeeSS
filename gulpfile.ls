require! {
  gulp
  webpack
  child_process
  nib
  connect
  'gulp-util'
  'gulp-jade'
  'gulp-stylus'
  'gulp-livereload'
  'serve-static'
  Promise: bluebird
  './src/livescript/components/Constants.ls'
}

const EXTENSION_ID = \eeabdaneafdojlhagbcpiiplpmabhnhl

gulp.task \default, <[watch]>

# Compile both the content script and background script.
# Since we have multiple entry points here, we can use webpack directly without
# bothering using gulp-webpack.
#
webpack-cache = {}

gulp.task \webpack, (cb)->
  webpack do
    entry:
      content-script: './src/livescript/contentScript.ls'
      content-setup: './src/livescript/contentSetup.ls'
      background: './src/livescript/background.ls'
      chrome-mock: './src/livescript/chromeMock.ls'
      report: './src/javascript/report.js'
      renderer-script: './src/livescript/rendererScript.ls'
    output:
      path: './build'
      filename: "[name].js",
    module:
      loaders:
        * test: /\.ls$/
          loader: 'livescript'
        * test: /\.coffee$/
          loader: 'coffee-loader'
        * test: /src\/javascript\/.+\.js$/
          loaders: <[jshint jsx-loader]>
    resolve:
      alias:
        'protocol': './protocol.coffee' # For interconnected components in Livereload

    cache: webpack-cache

    (err, stats) ->
      throw new gulp-util.PluginError \webpack, err if err

      # http://webpack.github.io/docs/node.js-api.html
      gulp-util.log '[webpack]', stats.toString!
      cb!

gulp.task \jade, ->
  gulp.src './src/jade/*.jade'
  .pipe gulp-jade pretty: true
  .pipe gulp.dest './build/'

gulp.task \stylus, ->
  gulp.src './src/stylus/*.styl'
  .pipe gulp-stylus use: [nib!]
  .pipe gulp.dest './build/assets/'

gulp.task \reload, ->
  (resolve, reject) <-! new Promise _
  resp = (err) ->
    if err
      reject!
    else
      resolve!
  child_process.exec "curl http://localhost:24601/r?ext=#{Constants.EXTENSION_ID}", resp
    ..stdout.pipe process.stdout
    ..stderr.pipe process.stderr

gulp.task \build, <[webpack jade stylus]>

gulp.task \watch, <[build]> ->
  gulp.watch './src/livescript/**/*', <[webpack reload]>
  gulp.watch './src/javascript/**/*' <[webpack]>
  gulp.watch './src/jade/*.jade', <[jade]>
  gulp.watch './src/stylus/*.styl', <[stylus]>

  # Static http server & livereload server for developing report pages
  server = connect!
  port = process.env.PORT || 5000
  server.use serve-static('build') .listen port
  console.log "Open http://localhost:#{port}/report.html to develop report page"

  livereload-server = gulp-livereload!
  livereload-server.changed!
  gulp.watch <[build/assets/*.css build/*.html build/report.js build/chromeMock.js]> .on \change, ->
    console.log "Change detected: #{it.path}"
    livereload-server.changed it.path
