define('main', function (require) {
  'use strict';
  // var rpc = require('libs/rpc');
  // var commands = {
  //   'terminal': require('apps/Terminal'),
  //   'browse-files': require('apps/FileBrowser'),
  //   'edit': require('apps/Editor'),
  // };
  var makeWindow = require('libs/window');

  var win = makeWindow(10, 10, 100, 100, 'Terminal');
  document.body.textContent = '';
  document.body.appendChild(win.el);
  console.log(win);

});
