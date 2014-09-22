/** @jsx React.DOM */

var React = require('react');
var SerializablePageDiff = require('../livescript/components/SerializablePageDiff.ls');
var IframeUtil = require('../livescript/components/IframeUtil.ls');
var ElementDifference = require('../livescript/components/ElementDifference.ls');
var Scroller = require('exports?Scroller!../../vendor/bower_components/scroller/src/Scroller.js');

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

        var diff, i, pageDiffLength = pageDiff.diffs.length;
        // Write diff id inside diff
        for(i=0; i<pageDiffLength; i+=1){
          pageDiff.diffs[i].id = i;
        }

        // Merge the overlapping bounding boxes
        //
        pageDiff.diffs.sort(function(di, dj){
          return di.boundingBox.top - dj.boundingBox.top;
        });

        var mergedDiffs = [],
            currentMergedDiff = new MergedDiff();

        for(i=0; i<pageDiffLength; i+=1){
          diff = pageDiff.diffs[i];

          if( !currentMergedDiff.isEmpty() &&
              !currentMergedDiff.isOverlapping(diff) ){
            // Not overlapping, open up a new MergedDiff instance
            //
            mergedDiffs.push(currentMergedDiff);
            currentMergedDiff = new MergedDiff();
          }

          currentMergedDiff.add(diff);
        }
        mergedDiffs.push(currentMergedDiff);

        // Prepare the diff list state data
        //
        var newData = that.state.data;
        for(i = 0; i < mergedDiffs.length; i+=1){
          newData.push({
            domWidth: pageDiff.width,
            domHeight: pageDiff.height,
            mergedDiff: mergedDiffs[i],
            dom: pageDiff.dom(),
            url: pageDiff.url,
            doctype: pageDiff.doctype
          });
        }

        that.setState({data: newData});
      }
    });
  },


  render: function(){
    var diffList = this.state.data.map(function(packed){
      var boxWidth = packed.mergedDiff.box.right - packed.mergedDiff.box.left,
          boxHeight = packed.mergedDiff.box.bottom - packed.mergedDiff.box.top;

      return (<Diff domWidth={packed.domWidth} domHeight={packed.domHeight}
                    boxWidth={boxWidth} boxHeight={boxHeight}
                    boxLeft={packed.mergedDiff.box.left} boxTop={packed.mergedDiff.box.top}
                    dom={packed.dom} url={packed.url}
                    doctype={packed.doctype}
                    diffs={packed.mergedDiff.diffs}></Diff>);
    });

    return (
      <div className="difflist">
        {diffList}
      </div>
    );
  }
});


var Diff = React.createClass({
  getInitialState: function(){
    return {
      isZoomed: false
    };
  },
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
            hintElem.id = "SEESS_POSITION_ANIMATE_"+diffId;


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


            styleElem.innerHTML += "#" + hintElem.id + "{" +
                "z-index: 99999; box-sizing: border-box; position: fixed; " +
                "border: 1px dashed red; background:rgba(255,0,0,0.1);" +
                "transform-origin: left top; opacity: 1;" +
                "-webkit-animation: SEESS_POSITION_" + diffId + " 3s ease-in-out 0s infinite;" +
                "will-change: transform; " + beforeRules +
              "}\n" +
              "@-webkit-keyframes SEESS_POSITION_" + diffId + " {to {"+afterRules+"opacity: 0.5;}}\n";

            iframeDoc.body.appendChild(hintElem);
          }
        }
      });
      iframeDoc.body.appendChild(styleElem);
    });
    IframeUtil.setDocument(iframeDoc, this.props.dom.cloneNode(true), this.props.doctype);
  },
  render: function(){
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

    var diffClasses = 'diff' + (this.state.isZoomed ? ' is-zoomed' : '');

    return (
      <div className={diffClasses} onKey>
        <div className="crop" onClick={this.setZoom} ref="iframeContainer">
          <iframe style={iframeStyle} ref="iframeElem"></iframe>
        </div>
        <p className ="url">{this.props.url}</p>
      </div>
    );

  },
  setZoom: function(){
    if(this.state.isZoomed){ return; }

    var that = this,
        isDragging = false,
        iframe = this.refs.iframeElem.getDOMNode(),
        iframeContainer = this.refs.iframeContainer.getDOMNode(),
        originalTransform = iframe.style.transform,
        // scroller = new Scroller(function(left, top){
        //   console.log(left, top);
        //   iframe.style.setProperty("transform", "translate("+(-left)+"px,"+(-top)+"px)", "important");
        // }, {zooming: false, animating: false, bouncing: false}),
        escCallback = function(e){
          if(e.which !== 27) { return; }
          window.removeEventListener('keydown', escCallback);
          // iframeContainer.removeEventListener('mousedown', mousedownCallback);
          // iframeContainer.removeEventListener('mouseup', mouseupCallback);
          // window.removeEventListener('mouseleave', mouseupCallback);
          // window.removeEventListener('mousemove', mousemoveCallback);

          that.setState({isZoomed: false});
        // },
        // mousedownCallback = function(e){
        //   isDragging = true;
        //   scroller.doTouchStart([e], e.timeStamp);
        //   // e.preventDefault();
        //   console.log('mousedown');
        // },
        // mouseupCallback = function(e){
        //   console.log('mouseup');
        //   isDragging = false;
        //   scroller.doTouchEnd(e.timeStamp);
        // },
        // mousemoveCallback = function(e){
        //   console.log(e);
        //   if(isDragging){
        //     scroller.doTouchMove([e], e.timeStamp);
        //   }
        };

    // scroller.setDimensions(window.innerWidth, window.innerHeight, iframe.clientWidth, iframe.clientHeight);
    // scroller.setPosition(0, 0);

    window.addEventListener('keydown', escCallback);
    // iframeContainer.addEventListener('mousedown', mousedownCallback);
    // iframeContainer.addEventListener('mouseup', mouseupCallback);
    // window.addEventListener('mouseleave', mouseupCallback);
    // window.addEventListener('mousemove', mousemoveCallback);

    this.setState({isZoomed: true});
  }
});


React.renderComponent(<ReportApp />, document.getElementById('body'));


function MergedDiff(){
  this.diffs = [];

  // A default that will update to the given diff by #add(diff) method
  //
  this.box = {
    left: Infinity,
    top: Infinity,
    right: -Infinity,
    bottom: -Infinity
  };
}

MergedDiff.prototype.isEmpty = function(){
  return this.diffs.length === 0;
};

MergedDiff.prototype.add = function(diff){
  // Merge diff and update the bounding box of merged diffs
  //

  this.box.left = (diff.boundingBox.left < this.box.left) ? diff.boundingBox.left : this.box.left;
  this.box.right = (diff.boundingBox.right > this.box.right) ? diff.boundingBox.right : this.box.right;
  this.box.top = (diff.boundingBox.top < this.box.top) ? diff.boundingBox.top : this.box.top;
  this.box.bottom = (diff.boundingBox.bottom > this.box.bottom) ? diff.boundingBox.bottom : this.box.bottom;

  this.diffs.push(diff);
};

MergedDiff.prototype.isOverlapping = function(diff){
  // Return if the merged diff overlaps with a diff
  //
  var leftMostBox, topMostBox, anotherBox;

  if(this.box.left <= diff.boundingBox.left){
    leftMostBox = this.box;
    anotherBox = diff.boundingBox;
  }else{
    leftMostBox = diff.boundingBox;
    anotherBox = this.box;
  }

  // Check if horizontally detached
  if(leftMostBox.right < anotherBox.left){
    return false;
  }

  if(this.box.top <= diff.boundingBox.top){
    topMostBox = this.box;
    anotherBox = diff.boundingBox;
  }else{
    topMostBox = diff.boundingBox;
    anotherBox = this.box;
  }

  // Check if vertically detached
  if(topMostBox.bottom < anotherBox.top){
    return false;
  }

  return true;
};