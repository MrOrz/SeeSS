require! {
  Connector: '../../../vendor/bower_components/livereload-js/src/connector.coffee'.Connector
  Options: '../../../vendor/bower_components/livereload-js/src/options.coffee'.Options
  Timer: '../../../vendor/bower_components/livereload-js/src/timer.coffee'.Timer
}

class LiveReloadClient
  const TAG = "[LiveReloadClient]"

  ({on-connect, on-reload, on-disconnect}) ->
    options = new Options
    options.host = 'localhost'
    @connector = new Connector options, WebSocket, Timer, do
      connecting: ~>
      socketConnected: ~>
      connected: ~>
        console.log TAG, 'livereload connected'
        on-connect! if on-connect

      error: (e) ~>
        console.log TAG, e.message

      disconnected: (reason, next-delay) ~>
        console.log TAG, 'disconnect', reason
        on-disconnect reason, next-delay if on-disconnect

      message: (msg) ~>
        return unless msg.command is \reload

        console.log TAG, \RELOAD!
        on-reload msg if on-reload

  shut-down: ->
    @connector.disconnect!

module.exports = LiveReloadClient
