define('apps/Terminal', function (require) {
  'use strict';

  // Load the terminal emulator library.
  var Term = require('libs/term');
  var getEnv = require('libs/agent-env');

  var charHeight = 16;
  var charWidth = 8;
  var clientKey;

  Terminal.title = 'Terminal';
  return Terminal;

  function* Terminal(call, run, cwd) {

    var win;
    clientKey = clientKey === undefined ? (clientKey = yield* call('key')) : clientKey;
    var env = yield* getEnv();
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
        args: [env.os === 'Linux' ? '-i' : '-l'],
        cwd: cwd || env.home,
        env: [
          'HOME=' + env.home,
          'USER=' + env.user,
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

      term.write(
        'You can send commands to the browser environment via special ' +
        '\x1b[34mrax\x1b[39m commands:\r\n\n' + [
          ['terminal', '[cwd]', 'Open a terminal at optional starting path.'],
          ['browse', 'folder*', 'Open File Browser at given directory paths.'],
          ['edit', 'file*', 'Open Text Editor at given file paths.'],
          ['view', 'file*', 'Open Image Viewer at given file paths.'],
        ].map(function (list) {
          return '  \x1b[34mrax \x1b[33m' + list[0] +
            ' \x1b[32m' + list[1] +
            ' \x1b[39m\r\n    ' + list[2] + '\r\n\n';
        }).join(''));

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
