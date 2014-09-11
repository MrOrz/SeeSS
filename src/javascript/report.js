/** @jsx React.DOM */

var React = require('react');
var SerializablePageDiff = require('../livescript/components/SerializablePageDiff.ls');
var IframeUtil = require('../livescript/components/IframeUtil.ls');

console.log('React', React);
console.log('chrome', chrome);
/*
var HelloMessage = React.createClass({
  render: function(){
    return <div>Hello {this.props.name}</div>;
  }
});

React.renderComponent(<HelloMessage name="Jacky"/>,
  document.getElementById('body'));
*/
window.pageDiffs = [];

var DiffList = React.createClass({
  
  getInitialState: function(){
    return {data: []};
  },

  componentDidMount: function(){
    var that = this;
    chrome.runtime.onMessage.addListener(function(message){
      var pageDiff;
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
        pageDiff = new SerializablePageDiff(message.data);
        console.log("<Message> Data arrived from background script", pageDiff);
        
        var newData = that.state.data;
        newData.push(pageDiff);
        that.setState({data: newData});

        // For debug.
        // TODO: Remove when going live!
        //
        pageDiffs.push(pageDiff);
      }
    });
  },


  render: function(){
    var DiffArray = this.state.data.map(function(diff){
      console.log(diff.dom());
      return (<Diff dom={diff.dom()}></Diff>);
    });

    return (
      <div className="difflist">
        {DiffArray}
      </div>
    );
  }
});


var Diff = React.createClass({
  render: function(){
    return (
      <div className="diff">
          <iframe src="http://www.ntu.edu.tw"></iframe>
      </div>
    );
  }
});


React.renderComponent(<DiffList />,
document.getElementById('body'));



// For debug.
// TODO: Remove when going live!
//



