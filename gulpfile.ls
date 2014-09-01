require! {
  gulp
  webpack
  child_process
  nib
  'gulp-util'
  'gulp-jade'
  'gulp-stylus'
  Promise: bluebird
}

const EXTENSION_ID = \eeabdaneafdojlhagbcpiiplpmabhnhl

gulp.task \default, <[watch]>

# Compile both the content script and background script.
# Since we have multiple entry points here, we can use webpack directly without
# bothering using gulp-webpack.
#
gulp.task \webpack, (cb)->
  webpack do
    entry:
      content-script: './src/livescript/contentScript.ls'
      background: './src/livescript/background.ls'
      chrome-mock: './src/livescript/chromeMock.ls'
      report: './src/javascript/report.js'
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
  child_process.exec "curl http://localhost:24601/r?ext=#{EXTENSION_ID}", resp
    ..stdout.pipe process.stdout
    ..stderr.pipe process.stderr

gulp.task \build, <[webpack jade stylus]>

gulp.task \watch, <[build]> ->
  gulp.watch ['./src/livescript/**/*', './src/javascript/**/*'], <[webpack reload]>
  gulp.watch './src/jade/*.jade', <[jade reload]>
  gulp.watch './src/stylus/*.styl', <[stylus reload]>
