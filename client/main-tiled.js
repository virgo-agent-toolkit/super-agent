define('main-tiled', function (require) {
  'use strict';
  var run = require('libs/run');
  var rpc = require('libs/rpc');
  var domBuilder = require('libs/dombuilder');
  run(function* () {
    var call = yield* rpc();
    console.log(call);
    console.log();
    document.body.textContent = '';
    document.body.appendChild(domBuilder(['h1', yield* call('getos')]));
  });
});
