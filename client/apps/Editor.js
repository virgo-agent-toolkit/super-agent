/*global CodeMirror*/
define('apps/Editor', function (require) {
  'use strict';

  var guessMime = require('libs/mime');

  Editor.title = 'Editor';
  return Editor;
  function* Editor(call, run, file) {
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
      });
      win.title = file;
      setTimeout(function () {
        cm.refresh();
      }, 0);
    }
  }
});
