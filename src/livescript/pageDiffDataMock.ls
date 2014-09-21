require! {
  page-diffs: 'json!../../test/fixtures/pagediffs-bootstrap.json'
}

unless location.href.match /^chrome-extension:/

  callbacks = []
  window.chrome =
    mock: yes

    runtime:
      on-message:
        add-listener: (cb) ->
          cb type: \PROCESS_START, data: {total: page-diffs.length}

          function consume
            cb do
              type: \PAGE_DIFF
              data: page-diffs.shift!

            if page-diffs.length > 0
              set-timeout consume, 500
            else
              cb type: \PROCESS_END

          set-timeout consume, 1000

  <- set-timeout _, 1500

  for cb in callbacks
    cb type: \PROCESS_START, data: {total: page-diffs.length}

  function consume
    data = page-diffs.shift!
    for cb in callbacks
      cb do
        type: \PAGE_DIFF
        data: data

    if page-diffs.length > 0
      set-timeout consume, 500
    else
      for cb in callbacks
        cb type: \PROCESS_END

  set-timeout consume, 1000