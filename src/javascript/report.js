/** @jsx React.DOM */

var React = require('react');
var SerializablePageDiff = require('../livescript/components/SerializablePageDiff.ls');
var IframeUtil = require('../livescript/components/IframeUtil.ls');
var ElementDifference = require('../livescript/components/ElementDifference.ls');

console.log('React', React);
console.log('chrome', chrome);

// Make React Debugging Chrome extension happy
window.React = React;


var ReportApp = React.createClass({
  render: function(){
    return (
      <div>
        <ReportHeader />
        <DiffList />
      </div>
    );
  }
});

var ReportHeader = React.createClass({
  getInitialState: function(){
    return {
      isInitial: true,
      isLoading: false,
      total: 0,
      done: 0
    };
  },
  componentDidMount: function(){
    // Message handling
    var that = this;
    chrome.runtime.onMessage.addListener(function(message){
      switch(message.type){
      case "PROCESS_START":
        that.setState({
          isLoading: true,
          isInitial: false,
          total: message.data.total,
          done: 0,
          startTimestamp: Date.now()
        });
        break;

      case "PROCESS_END":
        that.setState({
          isLoading: false,
          processingTime: (Date.now() - that.state.startTimestamp) / 1000
        });
        break;

      case "PAGE_DIFF":
        that.setState({
          done: that.state.done + 1
        });
      }
    });
  },
  render: function(){
    if(this.state.isInitial){
      return (
        <header>
          <h1>SeeSS</h1>
          <h3 id="loading">Start recording some interaction! :)</h3>
        </header>
      );
    }else{
      if(this.state.isLoading){
        return (
          <h3 id="loading">Loading... ({this.state.done} / {this.state.total})</h3>
        );
      }else{
        return (
          <h3 id="loading">Done in {this.state.processingTime} seconds.({this.state.done}/{this.state.total})</h3>
        );
      }
    }
  }
});


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
        that.setState({data: []});
        break;

      // The background script has done all processing.
      //
      case "PROCESS_END":
        console.log("<Message> Background script processing end");
        break;

      // The background script passes a SerializablePageDiff instance here.
      case "PAGE_DIFF":
        if(message.data === null){
          return;
        }
        pageDiff = new SerializablePageDiff(message.data);
        console.log("<Message> Data arrived from background script", pageDiff);

        var newData = that.state.data;

        var diff, i;
        // Write diff id inside diff
        for(i=0; i<pageDiff.diffs.length; i+=1){
          pageDiff.diffs[i].id = i;
        }


        for(i = 0; i < pageDiff.diffs.length; i+=1){
          diff = pageDiff.diffs[i];

          //Calculate BoundingBox, decide which is to push

          var diffPack={
            domWidth: pageDiff.width,
            domHeight: pageDiff.height,
            diffs: [diff],
            boxWidth: diff.boundingBox.right - diff.boundingBox.left,
            boxHeight: diff.boundingBox.bottom - diff.boundingBox.top,
            boxLeft: diff.boundingBox.left,
            boxTop: diff.boundingBox.top,
            dom: pageDiff.dom(),
            url: pageDiff.url,
            doctype: pageDiff.doctype
          };

          newData.push(diffPack);
        }

        that.setState({data: newData});
      }
    });
  },


  render: function(){
    var DiffArray = this.state.data.map(function(diff){
        return (<Diff domWidth={diff.domWidth} domHeight={diff.domHeight}
                      boxWidth={diff.boxWidth} boxHeight={diff.boxHeight}
                      boxLeft={diff.boxLeft} boxTop={diff.boxTop}
                      dom={diff.dom} url={diff.url}
                      doctype={diff.doctype}
                      diffs={diff.diffs}></Diff>);

    });

    return (
      <div className="difflist">
        {DiffArray}
      </div>
    );
  }
});


var Diff = React.createClass({
  componentDidMount: function(){
    var iframe = this.refs.iframeElem.getDOMNode(),
        diffs = this.props.diffs,
        iframeDoc = iframe.contentDocument,
        styleElem = iframeDoc.createElement('style');

    // Create animated repositioning hint
    //
    IframeUtil.waitForAssets(iframe.contentDocument).then(function(){
      diffs.forEach(function(diff){
        var diffId = diff.id,
            hintElem,
            currentRect,
            beforeRulesData, beforeRules, afterRules,
            elem = iframeDoc.querySelector('['+SerializablePageDiff.DIFF_ID_ATTR+'~="'+diffId+'"]');

        if(diff.type === ElementDifference.TYPE_MOD){
          if(diff.rect){
            currentRect = elem.getBoundingClientRect();

            hintElem = iframeDoc.createElement('div');
            hintElem.id = "SEESS_POSITION_ANIMATE";


            beforeRuleData = {
              left: (diff.rect.left && diff.rect.left.before) || currentRect.left,
              top: (diff.rect.top && diff.rect.top.before) || currentRect.top,
              width: (diff.rect.width && diff.rect.width.before) || currentRect.width,
              height: (diff.rect.height && diff.rect.height.before) || currentRect.height
            };

            beforeRules =
              "left: " + beforeRuleData.left + 'px;' +
              "top: " + beforeRuleData.top + 'px;' +
              "width: " + beforeRuleData.width + 'px;' +
              "height: " + beforeRuleData.height + 'px;';

            afterRules =
              "transform: translate(" + (currentRect.left-beforeRuleData.left) + 'px,' +
                                      (currentRect.top-beforeRuleData.top) + 'px) ' +
                         "scale(" + (currentRect.width / beforeRuleData.width) + ',' +
                                    (currentRect.height / beforeRuleData.height) + ');';


            styleElem.innerHTML += "#SEESS_POSITION_ANIMATE{" +
                "z-index: 99999; box-sizing: border-box; position: fixed; " +
                "border: 1px dashed red; background:rgba(255,0,0,0.1);" +
                "transform-origin: left top; opacity: 1;" +
                "-webkit-animation: SEESS_POSITION_" + diffId + " 3s ease-in-out 0s infinite;" +
                "will-change: transform; " + beforeRules +
              "}\n" +
              "@-webkit-keyframes SEESS_POSITION_" + diffId + " {to {"+afterRules+"opacity: 0.5;}}";

            iframeDoc.body.appendChild(hintElem);
          }
        }
      });
      iframeDoc.body.appendChild(styleElem);
    });
    IframeUtil.setDocument(iframeDoc, this.props.dom.cloneNode(true), this.props.doctype);
  },
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

    var originLeft = this.props.boxLeft + this.props.boxWidth/2,
        originTop  = this.props.boxTop + this.props.boxHeight/2;

    translate = 'translate(' + (cropSize/2-originLeft) + 'px,' + (cropSize/2-originTop) + 'px)';
    origin = originLeft + 'px ' + originTop + 'px';

    var iframeStyle= {
      width: this.props.domWidth,
      height: this.props.domHeight,
      transform: translate + ' ' + scale,
      transformOrigin: origin
    };

    return (
      <div className="diff">
        <div className="crop">
          <iframe style={iframeStyle} ref="iframeElem"></iframe>
        </div>
        <p className ="url"> {this.props.url} </p>
      </div>
    );

  }
});


React.renderComponent(<ReportApp />, document.getElementById('body'));


// For debug.
// TODO: Remove when going live!
//



