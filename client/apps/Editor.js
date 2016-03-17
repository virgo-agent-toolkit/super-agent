define('apps/Editor', function (require) {
  'use strict';
  var domBuilder = require('libs/dombuilder');

  // modes to include for codemirror
  // https://codemirror.net/mode/index.html
  // - sh
  // - ruby
  // - lua
  // - css
  // -- html
  // -- javscript
  // -- c
  // -- bat
  // -- elm
  // -- rust
  // -- python
  // -- php
  // -- go
  // -- xml
  // -- sql
  // -- nginx
  // -- dockerfile
  // -- markdown
  // -- yaml
  // -- json
  // -- toml
  // -- puppet
  // -- pgp
  // -- perl

  Editor.title = 'Editor';
  return Editor;
  function* Editor(call, file) {
    var content = yield* call('readfile', file);
    return function (win) {
      var root = domBuilder(['textarea', {
        style: {
          boxSizing: 'border-box',
          position: 'absolute',
          resize: 'none',
          width: '100%',
          border: 0,
          top: 0,
          left: 0,
          right: 0,
          bottom: 0
        }
      }, content]);
      win.container.appendChild(root);
      win.title = file + ' - Editor';
    };
  }
});
