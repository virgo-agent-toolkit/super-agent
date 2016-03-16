define('apps/Terminal', function (require) {
  'use strict';

  // Load the terminal emulator library.
  let Term = require('libs/term');

  // win.title = newTitle -- Update a window title
  // win.close() -- Close a window
  // win.focus() -- Steal focus to own window
  // win.container - container element
  // win.width - width in pixels of container
  // win.height - height of container in pixels
  return function* (win, call, cwd) {

    let clientKey = yield* call('key');
    let winsize = getWinsize(win.width, win.height);

    let [write, kill, resize] = yield* call('pty',
      '/bin/bash',
      winsize,
      {
        cwd: cwd,
        env: [
          'TERM=xterm-256color',
          'RAX_CLIENT_KEY=' + clientKey
        ]
      },
      function onData(chunk) {
        if (chunk !== undefined) {
          term.write(chunk);
        }
        else {
          console.log('Pty stream closed');
          kill(8);
        }
      },
      function onError(error) {
        console.error(error);
      },
      function onExit(code, signal) {
        console.log('child exited', code, signal);
      }
    );
    let term = new Term({
      cols: winsize[0],
      rows: winsize[1],
      screenKeys: true
    });

    term.on('data', write);

    term.on('title', function (title) {
      win.title = title;
    });

    win.container.textContent = '';
    term.open(win.container);

    return {
      // Called when the app's container is resized.
      resize: onResize,
      // Called when the app is closed.
      close: onClose,
    };

    function getWinsize(w, h) {
      return [
        Math.floor((w - 4.8 - 4.8) / 6.6125),
        Math.floor((h - 4.8 - 4.8) / 12.8)
      ];
    }

    function onResize(w, h) {
      let winsize = getWinsize(w, h);
      let cols = winsize[0], rows = winsize[1];
      // Send a resize to the remote PTY
      resize(cols, rows);
      // Tell the local terminal client to resize
      term.resize(cols, rows);
    }

    function onClose() {
      term.destroy();
    }
  };
});
