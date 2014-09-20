storage = window.__seess__ = {}

exports.set-item = (key, value) ->
  storage[key] = value


exports.get-item = (key) ->
  storage[key]