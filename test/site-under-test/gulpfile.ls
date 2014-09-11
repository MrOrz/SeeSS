# Path configuration
#

require! {
  connect
  gulp
  'gulp-livereload'
}


gulp.task \default, <[server]>


# Spin up a localhost server, default port = 5000
#
gulp.task \server, ->
  console.log 'Starting livereload server...'

  gulp.watch <[*.html css/* images/*]>
      .on 'change', gulp-livereload.changed

  gulp-livereload.listen!

  console.log 'Starting connect server...'
  port = process.env.PORT || 3000

  connect!
  .use connect.static('./')
  .listen port, ->
    console.log "Connect server starting at http://localhost:#port"
