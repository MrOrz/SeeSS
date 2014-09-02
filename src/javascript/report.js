/** @jsx React.DOM */

var React = require('react');
var SerializablePageDiff = require('../livescript/components/SerializablePageDiff.ls');

console.log('React', React);
console.log('chrome', chrome);

var HelloMessage = React.createClass({
  render: function(){
    return <div>Hello {this.props.name}</div>;
  }
});

React.renderComponent(<HelloMessage name="Johnson"/>,
  document.getElementById('body'));

chrome.runtime.onMessage.addListener(function(message){
  switch(message.type){

    // Background script starts processing a CSS or HTML change.
    //
    case "PROCESS_START":
    console.log("<Message> Background script processing started");
    break;

    // The background script has done all processing.
    //
    case "PROCESS_END":
    console.log("<Message> Background script processing end");
    break;

    // The background script passes a SerializablePageDiff instance here.
    case "PAGE_DIFF":
    console.log("<Message> Data arrived from background script", new SerializablePageDiff(message.data));
  }
});
