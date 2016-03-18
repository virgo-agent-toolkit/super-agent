define('main', function (require) {
  'use strict';
  var makeWindow = require('libs/window');
  var rpc = require('libs/rpc');
  var Terminal = require('apps/Terminal');
  var Editor = require('apps/Editor');
  var FileBrowser = require('apps/FileBrowser');
  var run = require('libs/run');

  var realCall;
  function* call(...args) {
    if (!realCall) {
      realCall = yield* rpc(runCommand);
    }
    return yield* realCall(...args);
  }

  var home;
  function* expandVars(path) {
    if (!path.match(/\$HOME/)) { return path; }
    if (!home) {
      home = yield* call('homedir');
    }
    return path.replace('$HOME', home);
  }

  var commands = {
    'terminal': function* (cwd) {
      if (cwd) { cwd = yield* expandVars(cwd); }
      var win = yield* launchApp(Terminal, cwd);
      win.focus();
    },
    'edit': function* (...files) {
      for (var file of files) {
        file = yield* expandVars(file);
        var win = yield* launchApp(Editor, file);
        win.focus();
      }
    },
    'browse': function* (...folders) {
      for (var folder of folders) {
        folder = yield* expandVars(folder);
        var win = yield* launchApp(FileBrowser, folder);
        win.focus();
      }
    },
  };

  window.onload = function () {
    document.body.textContent = '';
    runCommand('terminal');
    runCommand('browse', '$HOME');
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
  };


  function runCommand(name, ...args) {
    var command = commands[name];
    if (!command) { throw new Error('No such command: ' + name); }
    run(function* () {
      yield* command(...args);
    });
  }

  function* launchApp(App, ...args) {
    var app = yield* App(call, runCommand, ...args);
    var win = makeWindow(App.title, app);
    document.body.appendChild(win.el);
    return win;
  }

  function onDone(err) {
    if (err) { console.error(err.stack); }
  }

});
