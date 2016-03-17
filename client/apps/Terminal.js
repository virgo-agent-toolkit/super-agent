define('apps/Terminal', function (require) {
  'use strict';

  // Load the terminal emulator library.
  var Term = require('libs/term');

  var charHeight = 16;
  var charWidth = 8;

  Terminal.title = 'Terminal';
  return Terminal;

  function* Terminal(call, cwd) {

    var win;
    var clientKey = yield* call('key');
    var home = yield* call('homedir');
    var user = yield* call('getuser');
    var os = yield* call('getos');
    app.initialWidth = 80 * charWidth + 10; // Magic width for 80 cols?
    app.initialHeight = 24 * charHeight + 10; // Magic height for 24 rows?
    var winsize = getWinsize(app.initialWidth, app.initialHeight);
    var term = new Term({
      cols: winsize[0],
      rows: winsize[1],
      screenKeys: true
    });
    var oldCols, oldRows;

    // [write, kill, resize]
    var write, kill, resize;
    var out = yield* call('pty',
      '/bin/bash',
      winsize,
      {
        args: [os === 'Linux' ? '-i' : '--login'],
        cwd: cwd || home,
        env: [
          'HOME=' + home,
          'USER=' + user,
          'LC_ALL=en_US.utf8',
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
      onClose();
    }

    term.on('data', write);

    // win.title = newTitle -- Update a window title
    // win.destroy() -- Close a window
    // win.focus() -- Steal focus to own window
    // win.container - container element
    // win.width - width in pixels of container
    // win.height - height of container in pixels
    return app;

    function app(w) {
      win = w;
      term.on('title', function (title) {
        win.title = title;
      });

      win.container.textContent = '';
      win.container.style.backgroundColor = '#000';
      win.container.style.overflow = 'hidden';
      term.open(win.container);

      // Called when the app's container is resized.
      win.onResize = onResize;
      // Called when the app is closed.
      win.onClose = onClose;
    }


    function getWinsize(w, h) {
      return [
        Math.floor((w - 10) / charWidth),
        Math.floor((h - 10) / charHeight)
      ];
    }

    function onResize(w, h) {
      var winsize = getWinsize(w, h);
      var cols = winsize[0], rows = winsize[1];
      if (cols !== oldCols || rows !== oldRows) {
        // Send a resize to the remote PTY
        resize(cols, rows);
        // Tell the local terminal client to resize
        term.resize(cols, rows);
      }
      oldCols = cols;
      oldRows = rows;
    }

    var closed;
    function onClose() {
      if (closed) { return; }
      closed = true;
      kill(15);
      term.destroy();
      win.destroy();
    }
  }
});
