define('apps/Console', function (require) {
  'use strict';

  var getEnv = require('libs/agent-env');
  var domBuilder = require('libs/dombuilder');

  var charHeight = 16;
  var charWidth = 8;
  var clientKey;

  var configs = {
    OSX: ['/bin/bash', '-l'],
    Linux: ['/bin/bash', '-i'],
    Windows: ['cmd.exe'],
  };

  Console.title = 'Console';
  return Console;

  function* Console(call, run, cwd) {

    var win;
    clientKey = clientKey === undefined ? (clientKey = yield* call('key')) : clientKey;
    var env = yield* getEnv();
    app.initialWidth = 80 * charWidth + 10;
    app.initialHeight = 24 * charHeight + 10;

    var config = configs[env.os];
    var lineEnd = env.os === 'Windows' ? '\r\n' : '\n';

    var out = yield* call('spawn',
      config[0],
      {
        args: config.slice(1),
        cwd: cwd || env.home,
        env: [
          'HOME=' + env.home,
          'USER=' + env.user,
          'LC_ALL=en_US.utf8',
          'FIFE_CLIENT_KEY=' + clientKey
        ]
      },
      onData, onData, onError, onExit
    );

    var write = out[0];
    var kill = out[1];

    var ui = {};

    function scroll() {
      win.container.scrollTop = win.container.scrollHeight;
    }

    function prompt() {
      win.container.appendChild(domBuilder(['form$form',
        {onsubmit: onSubmit},
        ['input.command$input'],
      ], ui));
      ui.input.focus();
      scroll();
    }

    function command(line) {
      if (ui.form) {
        win.container.removeChild(ui.form);
        ui.form = null;
      }
      win.container.appendChild(domBuilder([
        ['pre.command', line],
        ['pre.output$out'],
      ], ui));
      scroll();
    }

    function onSubmit(evt) {
      evt.preventDefault();
      var value = ui.input.value;
      if (!value) { return; }
      command(value);
      write(ui.input.value + lineEnd);
      prompt();
    }

    function onData(chunk) {
      if (chunk !== undefined) {
        ui.out.textContent += chunk;
        scroll();
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

    // term.on('data', write);

    // win.title = newTitle -- Update a window title
    // win.destroy() -- Close a window
    // win.focus() -- Steal focus to own window
    // win.container - container element
    // win.width - width in pixels of container
    // win.height - height of container in pixels
    return app;

    function app(w) {
      win = w;

      win.container.textContent = '';
      win.container.style.backgroundColor = '#000';
      win.container.style.color = '#fff';
      win.container.style.overflow = 'auto';
      prompt();

      // Called when the app is closed.
      win.onClose = onClose;
      // Called when the window is focused
      win.onFocus = onFocus;
      win.onBlur = onBlur;
    }

    var closed;
    function onClose() {
      if (closed) { return; }
      closed = true;
      kill(15);
      win.destroy();
    }

    function onFocus() {
      ui.input.focus();
    }
    function onBlur() {
      ui.input.blur();
    }
  }
});
