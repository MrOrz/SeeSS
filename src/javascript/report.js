/** @jsx React.DOM */

var React = require('react');
var SerializablePageDiff = require('../livescript/components/SerializablePageDiff.ls');
var IframeUtil = require('../livescript/components/IframeUtil.ls');

console.log('React', React);
console.log('chrome', chrome);


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
        document.getElementById('loading').style.display = 'none';
        break;

        // The background script passes a SerializablePageDiff instance here.
        case "PAGE_DIFF":
        pageDiff = new SerializablePageDiff(message.data);
        console.log("<Message> Data arrived from background script", pageDiff);

        var newData = that.state.data;

        /*after rendering
            (window.getComputedStyle(id,css) Element.getBoundingClientRect)
        */
        /*
        diff = pageDiff.diffs[id]
        target = pageDiff.queryDiffId(id);*/
        var diff, i;
        for(i = 0; i < pageDiff.diffs.length; i+=1){
          diff = pageDiff.diffs[i]

          //Calculate BoundingBox, decide which is to push

          var diffPack={
            domWidth: pageDiff.width,
            domHeight: pageDiff.height,
            boxWidth: diff.boundingBox.right - diff.boundingBox.left,
            boxHeight: diff.boundingBox.bottom - diff.boundingBox.top,
            boxLeft: diff.boundingBox.left,
            boxTop: diff.boundingBox.top,
            dom: pageDiff.dom(),
            url: pageDiff.url
          };

          newData.push(diffPack);
        }

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
        return (<Diff domWidth={diff.domWidth} domHeight={diff.domHeight}
                      boxWidth={diff.boxWidth} boxHeight={diff.boxHeight}
                      boxLeft={diff.boxLeft} boxTop={diff.boxTop}
                      dom={diff.dom} url={diff.url}></Diff>);

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
    //var cropSize = document.getElementById('fakecrop').style.width;
    var cropSize = window.getComputedStyle(document.getElementById('fakecrop')).getPropertyValue('width');
    cropSize = parseInt(cropSize, 10);

console.log('BBwidth: ' + this.props.boxWidth + '\nBBheight: ' + this.props.boxHeight);

    var scale = '', translate = '', origin = '';
    var scaleX = cropSize / this.props.boxWidth;
    var scaleY = cropSize / this.props.boxHeight;

    if(scaleX < 1 || scaleY < 1){
      var scaleMin;
      if(scaleX < scaleY){
        scaleMin = scaleX;
      }
      else{
        scaleMin = scaleY;
      }
      scale = 'scale(' + scaleMin + ',' + scaleMin + ')';
    }

    translate = 'translate(' + this.props.boxLeft*(-1) + 'px,' + this.props.boxTop*(-1) + 'px)';
    origin = this.props.domWidth/2 + ' ' + this.props.domHeight/2;

    var iframeStyle= {
      width: this.props.domWidth,
      height: this.props.domHeight,
      transform: scale + ' ' +translate,
      transformOrigin: origin
    };

    return (
      <div className="diff">
        <div className="crop">
          <iframe style={iframeStyle} src="http://www.ntu.edu.tw"></iframe>
        </div>
        <p className ="url"> {this.props.url} </p>
      </div>
    );

  }
});


React.renderComponent(<DiffList />,
document.getElementById('body'));



// For debug.
// TODO: Remove when going live!
//



