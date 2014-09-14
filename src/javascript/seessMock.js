/*
  Fake localStorage and sessionStorage.

  Separates each renderer's localStorage.

  Credit: https://github.com/pivotal/jasmine/issues/299
*/

var localStorageData = JSON.stringify(localStorage),
    sessionStorageData = JSON.stringify(sessionStorage);

var storeFactory = function(jsonData) {
  var store;

  if(jsonData){
    store = JSON.parse(jsonData);
  }else{
    store = {};
  }

  store.getItem = function(key) {
    return this[key];
  };
  store.setItem = function(key, value) {
    this[key] = value.toString();
  };
  store.clear = function() {
    var key;
    for(key in this){
      if(this.hasOwnProperty(key) && key !== 'setItem' && key !== 'getItem' &&
         key !== 'clear' && key !== 'removeItem'){
        this[key] = undefined;
      }
    }
  };
  store.removeItem = function(key){
    this[key] = undefined;
  };

  return store;
};

Object.defineProperty(window, 'localStorage', { value: storeFactory(localStorageData) });
Object.defineProperty(window, 'sessionStorage', { value: storeFactory(sessionStorageData) });


/*
  Deterministic Math.random

  Credit: https://gist.github.com/mathiasbynens/5670917
*/

Math.random = (function() {
  var seed = 0x2F6E2B1;
  return function() {
    // Robert Jenkins’ 32 bit integer hash function
    seed = ((seed + 0x7ED55D16) + (seed << 12))  & 0xFFFFFFFF;
    seed = ((seed ^ 0xC761C23C) ^ (seed >>> 19)) & 0xFFFFFFFF;
    seed = ((seed + 0x165667B1) + (seed << 5))   & 0xFFFFFFFF;
    seed = ((seed + 0xD3A2646C) ^ (seed << 9))   & 0xFFFFFFFF;
    seed = ((seed + 0xFD7046C5) + (seed << 3))   & 0xFFFFFFFF;
    seed = ((seed ^ 0xB55A4F09) ^ (seed >>> 16)) & 0xFFFFFFFF;
    return (seed & 0xFFFFFFF) / 0x10000000;
  };
}());


/*
  Mock requestAnimationFrame so that the callbacks can get fired even when the page
  is rendered inside an iframe in the background page
*/

window.requestAnimationFrame = window.webkitRequestAnimationFrame = function(callback){
  setTimeout(callback, 0);
};