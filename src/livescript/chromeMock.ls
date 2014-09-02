require! {
  page-diffs: 'json!../../test/fixtures/pagediffs.json'
}

window.chrome =
  mock: yes

  runtime:
    on-message:
      add-listener: (cb) ->
        cb type: \PROCESS_START

        function consume
          cb do
            type: \PAGE_DIFF
            data: page-diffs.shift!

          if page-diffs.length > 0
            set-timeout consume, 500
          else
            cb type: \PROCESS_END

        set-timeout consume, 1000