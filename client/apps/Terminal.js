define('apps/Terminal', function (require) {
  'use strict';

  let rax = require('libs/rax');
  let Terminal = require('libs/term');

  rax.registerApp('terminal', function* (call, update, h, cwd) {
    let clientKey = yield* call('key');
    let [write, kill, resize] = yield* call('pty',
      '/bin/bash',
      [80,24],
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
    let term = new Terminal({
      cols: 80,
      rows: 24,
      screenKeys: true
    });

    term.on('data', write);

    term.on('title', function(title) {
      document.title = title;
    });

    document.body.textContent = '';
    term.open(document.body);

    term.write('\x1b[31mWelcome to term.js!\x1b[m\r\n');
  });
});
