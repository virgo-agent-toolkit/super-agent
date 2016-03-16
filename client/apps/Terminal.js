define('apps/Terminal', function (require) {
  'use strict';

  // Load the terminal emulator library.
  var Term = require('libs/term');

  return function* (call, cwd) {

    var clientKey = yield* call('key');
    app.initialWidth = 682; // Magic width for 80 cols?
    app.initialHeight = 394; // Magic height for 24 rows?
    var winsize = getWinsize(app.initialWidth, app.initialHeight);
    var term = new Term({
      cols: winsize[0],
      rows: winsize[1],
      screenKeys: true
    });

    // [write, kill, resize]
    var write, kill, resize;
    var out = yield* call('pty',
      '/bin/bash',
      winsize,
      {
        cwd: cwd,
        env: [
          'TERM=xterm-256color',
          'RAX_CLIENT_KEY=' + clientKey
        ]
      },
      onData, onError, onExit
    );
    write = out[0];
    kill = out[1];
    resize = out[2];

    function onData(chunk) {
      if (chunk !== undefined) {
        term.write(chunk);
      }
      else {
        console.log('Pty stream closed');
        kill(15);
      }
    }
    function onError(error) {
      console.error(error);
    }
    function onExit(code, signal) {
      console.log('child exited', code, signal);
    }


    term.on('data', write);

    // win.title = newTitle -- Update a window title
    // win.close() -- Close a window
    // win.focus() -- Steal focus to own window
    // win.container - container element
    // win.width - width in pixels of container
    // win.height - height of container in pixels
    return app;

    function app(win) {
      term.on('title', function (title) {
        win.title = title;
      });

      win.container.textContent = '';
      win.container.style.backgroundColor = '#000';
      console.log(win.container);
      term.open(win.container);

      // Called when the app's container is resized.
      win.onResize = onResize;
      // Called when the app is closed.
      win.onClose = onClose;
    }


    function getWinsize(w, h) {
      return [
        Math.floor((w - 10) / 8.4),
        Math.floor((h - 10) / 16)
      ];
    }

    function onResize(w, h) {
      var winsize = getWinsize(w, h);
      var cols = winsize[0], rows = winsize[1];
      // Send a resize to the remote PTY
      resize(cols, rows);
      // Tell the local terminal client to resize
      term.resize(cols, rows);
    }

    function onClose() {
      term.destroy();
      kill(15);
    }
  };
});
