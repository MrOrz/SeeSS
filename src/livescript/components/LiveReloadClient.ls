require! {
  Connector: '../../../vendor/bower_components/livereload-js/src/connector.coffee'.Connector
  Options: '../../../vendor/bower_components/livereload-js/src/options.coffee'.Options
  Timer: '../../../vendor/bower_components/livereload-js/src/timer.coffee'.Timer
}

class LiveReloadClient
  const TAG = "[LiveReloadClient]"

  (reload-callback) ->
    options = new Options
    options.host = 'localhost'
    @connector = new Connector options, WebSocket, Timer, do
      connecting: ~>
      socketConnected: ~>
      connected: ~>
        console.log TAG, 'livereload connected'
      error: (e) ~>
        console.log TAG, e.message
      disconnected: (reason, next-delay) ~>
        console.log TAG, 'disconnect', reason
      message: (msg) ~>
        return unless msg.command is \reload

        console.log TAG, \RELOAD!
        reload-callback msg

  shut-down: ->
    @connector.disconnect!

module.exports = LiveReloadClient