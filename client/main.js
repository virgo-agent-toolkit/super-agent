define('main', function (require) {
  'use strict';
  var makeWindow = require('libs/window');
  var rpc = require('libs/rpc');
  var Terminal = require('apps/Terminal');
  var Editor = require('apps/Editor');
  var FileBrowser = require('apps/FileBrowser');
  var run = require('libs/run');

  var call;
  var commands = {
    'terminal': function* (cwd) {
      var win = yield* launchApp(Terminal, cwd);
      win.focus();
    },
    'edit': function* (...files) {
      for (var file of files) {
        var win = yield* launchApp(Editor, file);
        win.focus();
      }
    },
    'browse': function* (...folders) {
      for (var folder of folders) {
        var win = yield* launchApp(FileBrowser, folder);
        win.focus();
      }
    },
  };

  document.body.textContent = '';

  runCommand('terminal');
  // runCommand('edit',
    // '/Users/tim8019/Code/super-agent/client/main.js',
    // '/Users/tim8019/Code/super-agent/client/index.html',
    // '/Users/tim8019/Code/super-agent/client/assets/style.css',
    // '/Users/tim8019/Code/ele/contrib/alarm_loading_metrics.rb',
    // '/Users/tim8019/Code/super-agent/api/admin-panel/src/Main.elm',
    // '/Users/tim8019/Code/ele/java/graphs.py'
    // '/Users/tim8019/Code/jack.rs/src/main.rs'
    // '/Users/tim8019/Code/luv/src/luv.c',
    // '/Users/tim8019/Code/luv/src/luv.h',
    // '/Users/tim8019/Code/lit/get-lit.sh'
  // );

  function runCommand(name, ...args) {
    var command = commands[name];
    if (!command) { throw new Error('No such command: ' + name); }
    run(function* () {
      yield* command(...args);
    }, onDone);
  }

  function* launchApp(App, ...args) {
    if (!call) { call = yield* rpc(runCommand); }
    var app = yield* App(call, ...args);
    var win = makeWindow(App.title, app);
    document.body.appendChild(win.el);
    return win;
  }

  function onDone(err) {
    if (err) { throw err; }
  }

});
