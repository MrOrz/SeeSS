/** @jsx React.DOM */

var React = require('react');

console.log('React', React);
console.log('chrome', chrome);

var HelloMessage = React.createClass({
  render: function(){
    return <div>Hello {this.props.name}</div>;
  }
});

React.renderComponent(<HelloMessage name="John"/>,
  document.getElementById('body'));