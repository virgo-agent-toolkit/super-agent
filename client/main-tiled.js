
define('main-tiled', function (require) {
  'use strict';
  var desktop = require('libs/tiled');
  document.body.textContent = '';
  document.body.appendChild(desktop.el);
  var nextChar = 'A'.charCodeAt(0);
  window.onkeyup = function (evt) {
    if (evt.key !== 'n') { return; }
    evt.stopPropagation();
    var name = 'Window ' + String.fromCharCode(nextChar++);
    desktop.newAutoWindow(name);
  };
  // var run = require('libs/run');
  // var rpc = require('libs/rpc');

});
