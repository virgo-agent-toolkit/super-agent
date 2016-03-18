/*global CodeMirror*/
define('apps/Editor', function (require) {
  'use strict';

  var guessMime = require('libs/mime');
  var run = require('libs/run');

  Editor.title = 'Editor';
  return Editor;
  function* Editor(call, runCommand, file) {
    var mime = guessMime(file, 'text/plain');
    if (mime === 'text/plain') {
      console.log('no mime found for', file);
    }
    var content = yield* call('readfile', file);
    app.initialWidth = 550;
    app.initialHeight = 350;
    return app;
    function app(win) {
      var cm = new CodeMirror(win.container, {
        value: content,
        mode: mime,
        theme: 'material',
        keyMap: 'sublime',
        lineNumbers: false,
        rulers: [{ column: 80 }],
        autoCloseBrackets: true,
        matchBrackets: true,
        showCursorWhenSelecting: true,
        styleActiveLine: true,
        extraKeys: {
          'Ctrl-S': saveCode,
        },
      });
      cm.on('change', refresh);
      function refresh() {
        var prefix  = (cm.getDoc().getValue() === content ? '' : '*');
        win.title = prefix + file;
      }
      function saveCode() {
        var data = cm.getDoc().getValue();
        run(function*() {
          yield* call('writefile', file, data);
          content = data;
          refresh();
        });
      }
      setTimeout(function () {
        cm.refresh();
        refresh();
      }, 0);
    }
  }
});
