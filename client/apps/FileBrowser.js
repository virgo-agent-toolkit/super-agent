define('apps/FileBrowser', function (require) {
  'use strict';

  var domBuilder = require('libs/dombuilder');
  var run = require('libs/run');
  var pathJoin = require('libs/pathjoin');
  var guessMime = require('libs/mime');

  var typeToName = {
    file: 'doc',
    directory: 'folder',
    link: 'link',
    fifo: 'box',
    socket: 'plug',
    char: 'tty',
    block: 'cubes',
  };

  // Available icons:
  //   file-image
  //   file-archive
  //   file-audio
  //   file-video
  //   file-code
  //   doc
  //   doc-text
  //   folder
  //   link
  //   cog
  //   cubes
  //   plug
  //   tty
  //   box

  var mimeMap = [
    /^image\//, 'file-image',
    /compressed$/, 'file-archive',
    /zip$/, 'file-archive',
    'text/plain', 'doc-text',
    /^audio\//, 'file-audio',
    /^video\//, 'file-video',
  ];
  
  var textIcons = {
    'doc': true,
    'doc-text': true,
    'file-code': true,
  };
  
  function isText(name) {
    return textIcons[getIcon(name, 'file')];
  }

  function isImage(name) {
    return getIcon(name, 'file') === 'file-image';
  }

  function getIcon(name, type) {
    var mime;
    if (type === 'file' && (mime = guessMime(name))) {
      if (!mime) { return typeToName.file; }
      for (var i = 0; i < mimeMap.length; i += 2) {
        if (mime.match(mimeMap[i])) { return mimeMap[i + 1]; }
      }
      return 'file-code';
    }
    return typeToName[type] || 'cog';
  }

  FileBrowser.title = 'FileBrowser';
  return FileBrowser;
  function* FileBrowser(call, runCommand, initialRoot) {
    var win;
    return app;

    function navigate(root) {
      win.title = root;
      win.container.textContent = '';
      var $ = {};
      domBuilder(['ul$root', {style: {
        listStyleType: 'none'
      }}], $);
      win.container.appendChild($.root);
      run(function*() {
        if (root !== '/') { onEntry('..', 'directory'); }
        yield* call('scandir', root, onEntry);
        function onEntry(name, type) {
          if (name !== '..' && name[0] === '.') { return; }
          $.root.appendChild(domBuilder(
            ['li', {onclick: go}, ['i.icon-' + getIcon(name, type)], name]
          ));
          function go() {
            var path = pathJoin(root, name);
            if (type === 'directory') { navigate(path); }
            else if (type === 'file') { 
              if (isText(path)) {
	            runCommand('edit', path); 
              }
              else if (isImage(path)) {
                runCommand('view', path);
              }
            }
          }
        }
      });
    }

    function app(w) {
      win = w;
      win.container.style.backgroundColor = '#ddd';
      return navigate(initialRoot);
    }
  }

});
