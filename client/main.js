define('main', function (require) {
  'use strict';
  var makeWindow = require('libs/window');
  var rpc = require('libs/rpc');
  var Terminal = require('apps/Terminal');
  var run = require('libs/run');

  var aepUrl = 'ws://localhost:8000/request/fc1eb9f7-69f0-4079-9e74-25ffd091022a';
  run(function* () {
    var call = yield* rpc(aepUrl);
    var app = yield* Terminal(call, '/Users/tim8019/Code/');
    var win = makeWindow('Terminal', app);
    document.body.textContent = '';
    document.body.appendChild(win.el);
  }, console.log.bind(console));
});
