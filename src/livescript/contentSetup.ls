require! {
  './components/ContentScriptStorage.ls'
}

ContentScriptStorage.set-item 'localStorage', JSON.stringify(localStorage)
