require! {
  gulp
  webpack
  child_process
  'gulp-util'
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
    output:
      path: './build'
      filename: "[name].bundle.js",
    module:
      loaders:
        * test: /\.ls$/
          loader: 'livescript'
        ...
    (err, stats) ->
      throw new gulp-util.PluginError \webpack, err if err

      # http://webpack.github.io/docs/node.js-api.html
      gulp-util.log '[webpack]', stats.toString!
      cb!

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

gulp.task \watch, ->
  gulp.watch './src/livescript/**/*', <[webpack reload]>