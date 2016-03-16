define('main', function (require) {
  'use strict';
  // let rpc = require('libs/rpc');
  // let commands = {
  //   'terminal': require('apps/Terminal'),
  //   'browse-files': require('apps/FileBrowser'),
  //   'edit': require('apps/Editor'),
  // };
  let makeWindow = require('libs/window');

  let win = makeWindow(10, 10, 100, 100, 'Terminal');
  document.body.textContent = '';
  document.body.appendChild(win.el);
  console.log(win);

});
