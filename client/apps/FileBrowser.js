define('apps/FileBrowser', function (require) {
  'use strict';

  var domBuilder = require('libs/dombuilder');
  var run = require('libs/run');

  var typeToName = {
    file: 'doc',
    directory: 'folder',
    link: 'link',
    fifo: 'box',
    socket: 'plug',
    char: 'tty',
    block: 'cubes',
  };
  var extensionToName = {
    jpg: 'file-image',
    jpeg: 'file-image',
    png: 'file-image',
    gif: 'file-image',
    js: 'file-code',
    lua: 'file-code',
    html: 'file-code',
    xml: 'file-code',
    rb: 'file-code',
    c: 'file-code',
    h: 'file-code',
    sh: 'file-code',
    css: 'file-code',
    elm: 'file-code',
    rs: 'file-code',
    py: 'file-code',
    gz: 'file-archive',
    zip: 'file-archive',
    bz: 'file-archive',
    tgz: 'file-archive',
    txt: 'doc-text',
    wav: 'file-audio',
    mp3: 'file-audio',
    aac: 'file-audio',
    mpg: 'file-video',
    m4v: 'file-video',
    fla: 'file-video',
    swf: 'file-video',
  };

  function getIcon(name, type) {
    if (type === 'file') {
      return extensionToName[name.match(/[^.]*$/)[0]] || typeToName.file;
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
          $.root.appendChild(domBuilder(
            ['li', {onclick: go}, ['i.icon-' + getIcon(name, type)], name]
          ));
          function go() {
            var path = root + (root === '/' ? '' : '/') + name;
            if (type === 'directory') { navigate(path); }
            else if (type === 'file') { runCommand('edit', path); }
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
