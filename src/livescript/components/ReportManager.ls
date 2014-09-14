# A singleton class that manages Report page tab
#

require! {
  './Message.ls'
  './Constants.ls'
  Promise: 'bluebird'
}

const TAG = "[ReportManager]"

ReportManager = do ->
  var report-tab-id

  # Reset report-tab-id when tab closed
  #
  chrome.tabs.on-removed.add-listener (tab-id) ->
    if tab-id is report-tab-id
      report-tab-id := null

  return do
    open: ->
      # Opens the tab and resolves to the opened tab ID
      #
      if report-tab-id
        return Promise.resolve(report-tab-id)

      else
        return new Promise (resolve, reject) ->
          chrome.tabs.create do
            url: "chrome-extension://#{Constants.EXTENSION_ID}/report.html"
            active: true
            (tab) ->
              report-tab-id := tab.id
              resolve tab.id

    start: (total) !->
      # Signals the report page that background script had started processing
      #
      <- @open!then
      m = new Message \PROCESS_START, total: total
      m.send report-tab-id

    send: (page-diff) !->
      # Send SerializablePageDiff instance to report page
      #
      <- @open!then
      m = new Message \PAGE_DIFF, page-diff
      m.send report-tab-id

    end: !->
      # Signals the report page that background script had done processing
      #
      <- @open!then
      m = new Message \PROCESS_END
      m.send report-tab-id


module.exports = ReportManager