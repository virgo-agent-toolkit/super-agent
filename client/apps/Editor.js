define('apps/Editor', function () {
  'use strict';

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
  function* Editor(call, ...files) {
    return function (win) {
    };
  };
});
