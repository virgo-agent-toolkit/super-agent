define('libs/window', function (require) {
  'use strict';

  var domBuilder = require('libs/dombuilder');
  var drag = require('libs/drag-helper');

  var windowWidth = window.innerWidth,
      windowHeight = window.innerHeight;

  var windows = [];
  var focused = null;
  var nextZ = 1;

  window.addEventListener('resize', function () {
    var newWidth = window.innerWidth;
    var newHeight = window.innerHeight;
    if (newWidth === windowWidth && newHeight === windowHeight) { return; }
    windowWidth = newWidth;
    windowHeight = newHeight;
    windows.forEach(function (win) {
      win.refresh();
    });
  });

  return makeWindow;

  // app.width - desired initial width
  // app.height - desired initial height
  function makeWindow(title, app) {

    var width = app.initialWidth || 320;
    var height = app.initialHeight || 200;
    var left = Math.floor(Math.random() * (windowWidth - width - 30)) + 5;
    var top = Math.floor(Math.random() * (windowHeight - height - 62)) + 5;
    var zIndex = nextZ++;

    var maximized = false;
    var isDark = false;
    var state = {};

    var northProps = drag(north);
    var northEastProps = drag(northEast);
    var eastProps = drag(east);
    var southEastProps = drag(southEast);
    var southProps = drag(south);
    var southWestProps = drag(southWest);
    var westProps = drag(west);
    var northWestProps = drag(northWest);
    var titleBarProps = drag(titleBar);

    var win = {
      get width() { return width; },
      get height() { return height; },
      get title() { return title; },
      set title(newTitle) {
        title = newTitle;
        refresh();
        return title;
      },
      destroy: destroy,
      focus: focus,
      refresh: refresh,
    };

    domBuilder(['$el',
      {
        onmousedown: focus, ontouchstart: focus,
      },
      ['.content$container'],
      ['.resize.n', northProps],
      ['.resize.ne', northEastProps],
      ['.resize.e', eastProps],
      ['.resize.se', southEastProps],
      ['.resize.s', southProps],
      ['.resize.sw', southWestProps],
      ['.resize.w', westProps],
      ['.resize.nw', northWestProps],
      ['.title-bar$titleBar', titleBarProps, title],
      ['.max-box$maxBox', {onclick:onMaxClick}],
      ['.close-box', {onclick:onCloseClick},'✖'],
    ], win);

    windows.push(win);
    refresh();
    app(win);

    return win;

    function refresh() {
      // Manually run constraints that edges must be inside desktop and
      // window must be at least 200x100
      var right = left + width;
      if (right < 10) { right = 10; }
      if (left > windowWidth - 10) { left = windowWidth - 10; }
      var mid = ((left + right) / 2) | 0;
      if (mid < ((windowWidth / 2) | 0)) {
        if (right < left + 200) { right = left + 200; }
        width = right - left;
        if (width > windowWidth) {
          left += width - windowWidth;
          width = windowWidth;
        }
      }
      else {
        if (left > right - 200) { left = right - 200; }
        width = right - left;
        if (width > windowWidth) { width = windowWidth; }
      }

      var bottom = top + height;
      if (bottom < 10) { bottom = 10; }
      if (top > windowHeight - 10) { top = windowHeight - 10; }
      mid = ((top + bottom) / 2) | 0;
      if (mid < ((windowHeight / 2) | 0)) {
        if (bottom < top + 100) { bottom = top + 100; }
        height = bottom - top;
        if (height > windowHeight) {
          top += height - windowHeight;
          height = windowHeight;
        }
      }
      else {
        if (top > bottom - 100) { top = bottom - 100; }
        height = bottom - top;
        if (height > windowHeight) { height = windowHeight; }
      }

      var ewidth, eheight;
      if (maximized) {
        ewidth = windowWidth;
        eheight = windowHeight - 32;
      }
      else {
        ewidth = width;
        eheight = height;
      }

      var style = maximized ? (
        'top: -10px;' +
        'left: -10px;' +
        'right: -10px;' +
        'bottom: -10px;'
      ) : (
        'width: ' + (width + 20 )+ 'px;' +
        'height: ' + (height + 52) + 'px;' +
        'transform: translate3d(' + left + 'px,' + top + 'px,0);' +
        'webkitTransform: translate3d(' + left + 'px,' + top + 'px,0);'
      );
      style += 'z-index: ' + zIndex + ';';

      var classes = ['window', isDark ? 'dark' : 'light'];
      if (focused === win) {
        classes.push('focused');
      }
      classes = classes.join(' ');

      if (title !== state.title) {
        win.titleBar.textContent = title;
      }
      if (win.onResize && (ewidth !== state.ewidth || eheight !== state.eheight)) {
        win.onResize(ewidth, eheight);
      }
      if (maximized !== state.maximized) {
        win.maxBox.textContent = maximized ? '▼' : '▲';
      }
      if (style !== state.style) {
        win.el.setAttribute('style', style);
      }
      if (classes !== state.classes) {
        win.el.setAttribute('class', classes);
      }

      state = {
        title: title,
        maximized: maximized,
        style: style,
        ewidth: ewidth,
        eheight: eheight,
        classes: classes,
      };

    }

    function focus() {
      if (focused === win) { return; }
      var old = focused;
      focused = win;
      zIndex = nextZ++;
      if (old) { old.refresh(); }
      refresh();
    }

    var destroyed;
    function destroy() {
      if (destroyed) { return; }
      destroyed = true;
      if (app.onClose) { app.onClose(); }
      windows.splice(windows.indexOf(win), 1);
      win.el.parentElement.removeChild(win.el);
    }

    function onMaxClick(evt) {
      evt.stopPropagation();
      maximized = !maximized;
      refresh();
      focus();
    }

    function onCloseClick(evt) {
      evt.stopPropagation();
      destroy();
    }

    function north(dx, dy) {
      height -= dy;
      top += dy;
      refresh();
    }
    function northEast(dx, dy) {
      height -= dy;
      top += dy;
      width += dx;
      refresh();
    }
    function east(dx) {
      width += dx;
      refresh();
    }
    function southEast(dx, dy) {
      height += dy;
      width += dx;
      refresh();
    }
    function south(dx, dy) {
      height += dy;
      refresh();
    }
    function southWest(dx, dy) {
      height += dy;
      width -= dx;
      left += dx;
      refresh();
    }
    function west(dx) {
      width -= dx;
      left += dx;
      refresh();
    }
    function northWest(dx, dy) {
      height -= dy;
      top += dy;
      width -= dx;
      left += dx;
      refresh();
    }
    function titleBar(dx, dy) {
      top += dy;
      left += dx;
      refresh();
    }
  }
});
