define('ui/desktop', function (require) {
  'use strict';

  let AppWindow = require('ui/app-window');
  let commands = {
    'terminal': require('apps/Terminal'),
    'browse': require('apps/Browser'),
    'edit': require('apps/Editor')
  };
  let rpc = require('libs/rpc');

  return Desktop;

  function Desktop(emit, refresh) {
    let isDark = false;
    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('resize', onResize);
    let width = window.innerWidth;
    let height = window.innerHeight;
    let windows = [
      { id: genId(),

        title: 'config.jon', code: config.get(), mode: 'jon' },

    ];
      // { id: genId(),
      //   title: 'bananas/samples/maze.jkl', code: jkl, mode: 'jackl' },

    return {
      render: render,
      on: {
        destroy: onWindowDestroy,
        focus: onWindowFocus
      }
    };

    function findWindow(id) {
      for (let i = 0; i < windows.length; i++) {
        if (windows[i].id === id) { return i; }
      }
      throw new Error('Invalid window id: ' + id);
    }

    function onWindowDestroy(id) {
      windows.splice(findWindow(id), 1);
      refresh();
    }

    function onWindowFocus(id) {
      let dirty = false;
      for (let i = 0; i < windows.length; i++) {
        let window = windows[i];
        let focused = window.id === id;
        if (focused !== window.focused) {
          window.focused = focused;
          dirty = true;
        }
        windows[i].focused = windows[i].id === id;
      }
      if (dirty) { refresh(); }
    }

    function onResize() {
      let newWidth = window.innerWidth;
      let newHeight = window.innerHeight;
      if (newWidth !== width || newHeight !== height) {
        width = newWidth;
        height = newHeight;
        refresh();
      }
    }

    function onKeyDown(evt) {
      let mod = (evt.ctrlKey  ? 1 : 0) |
                (evt.shiftKey ? 2 : 0) |
                (evt.altKey   ? 4 : 0) |
                (evt.metaKey  ? 8 : 0);
      if (mod === 1 && evt.keyCode === 66) {
        // Control-B - toggle theme
        evt.preventDefault();
        isDark = !isDark;
        refresh();
      }
    }

    function render() {
      return windows.map(function (props) {
        let ui = [AppWindow, width, height, isDark, props,
          [props.App, isDark, props]
        ];
        ui.key = props.id;
        return ui;
      });
    }
  }


  function genId() {
    return Date.now().toString(36) + (Math.random() * 0x100000000).toString(36);
  }
});
