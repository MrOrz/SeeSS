mock-data-chunk1 =
  yo: \yoyoyoy1

mock-data-chunk2 =
  yo2: \yoyoo2

mock-data-chunk3 =
  yo3: \yoyoo3

window.chrome =
  mock: yes

  runtime:
    on-message:
      add-listener: (cb) ->
        <- set-timeout _, 1000
        cb mock-data-chunk1
        <- set-timeout _, 300
        cb mock-data-chunk2
        <- set-timeout _, 700
        cb mock-data-chunk3


