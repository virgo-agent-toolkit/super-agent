/*global CodeMirror*/
define('apps/Editor', function () {
  'use strict';
  // modes to include for codemirror
  // https://codemirror.net/mode/index.html

  var modes = {
    js: 'javascript',
    lua: 'lua',
    html: 'htmlmixed',
    xml: 'xml',
    rb: 'ruby',
    c: 'text/x-c',
    h: 'text/x-chdr',
    sh: 'text/x-sh',
    css: 'text/css',
    elm: 'text/x-elm',
    // -- bat
    rs: 'text/x-rustsrc',
    py: 'text/x-python',
    // -- json
    // -- nginx
    // -- php
    // -- go
    // -- sql
    // -- dockerfile
    // -- markdown
    // -- yaml
    // -- toml
    // -- puppet
    // -- pgp
    // -- perl
  };

  Editor.title = 'Editor';
  return Editor;
  function* Editor(call, file) {
    var extension = file.match(/[^.]*$/)[0];
    var mode = modes[extension] || 'plaintext';
    console.log(mode);
    var content = yield* call('readfile', file);
    app.initialWidth = 550;
    app.initialHeight = 350;
    return app;
    function app(win) {
      var cm = new CodeMirror(win.container, {
        value: content,
        mode: mode,
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
