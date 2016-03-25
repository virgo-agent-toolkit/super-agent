define('libs/tiled', function (require) {
  'use strict';

  var domBuilder = require('libs/dombuilder');
  var drag = require('libs/drag-helper');

  var last = null;
  function setHover(win) {
    if (win === last) { return; }
    if (last) {
      var style = last.hoverEl.style;
      style.top = 0;
      style.left = 0;
      style.right = 'auto';
      style.bottom = 'auto';
      style.width = 0;
      style.height = 0;
      last.quadrant = 'none';
    }
    last = win;
  }

  var windowDragging = null;
  var hoverback = null;
  function selectQuadrant(callback) {
    if (hoverback) {
      throw new Error('already in hover select mode');
    }
    hoverback = callback;
    onMouseMove();
  }

  function doQuadrant() {
    if (!(hoverback && last)) { return; }
    var cb = hoverback;
    hoverback = null;
    cb(null, last);
    setHover(null);
  }

  function onWindowDrop(err, win) {
    var self = windowDragging;
    windowDragging = null;
    if (self.dragging !== win) {
      self.dragging.parent.remove(self.dragging);
    }
    win.add(self);
    self.dragging = null;
    self.el.classList.remove('moving');
    self.el.setAttribute('style', '');
    refresh();
  }

  function onMouseUp() {
    if (windowDragging) { doQuadrant(); }
  }

  var mx, my;
  function onMouseMove(evt) {
    if (evt) {
      mx = evt.clientX;
      my = evt.clientY;
    }
    if (!hoverback) { return; }
    function find(node, ox, oy) {
      if (mx < ox ||
          my < oy ||
          mx > ox + node.width ||
          my > oy + node.height) {
        return;
      }
      if (node instanceof Split) {
        return find(node.first, ox, oy) || (node.isVertical ?
          find(node.second, ox, oy + node.firstSize + 10) :
          find(node.second, ox + node.firstSize + 10, oy));
      }
      if (node instanceof Desktop) {
        return find(node.child, ox, oy);
      }
      return node;
    }
    var node = find(desktop, 0, 0);
    if (node && node.onMove) { node.onMove(mx, my); }
  }
  var focused;

  function Window(title) {
    this.title = title;
    this.width = 0;
    this.height = 0;
    domBuilder(['.cell.window$el',
      { onclick: this.onFocus.bind(this) },
      ['.title$titleEl',
        drag(this.onDrag.bind(this)),
        title],
      ['.close$closeEl',
        { onclick: this.onClose.bind(this) },
        '✖'],
      ['.content$contentEl'],
      ['.hover$hoverEl',
        { onclick: this.onClick.bind(this) }],
    ], this);
  }
  Window.prototype.onFocus = function () {
    if (this === focused) { return; }
    if (focused) {
      focused.el.classList.remove('focused');
    }
    focused = this;
    focused.el.classList.add('focused');
    // TODO: tell app about focus
  };
  Window.prototype.setTitle = function (title) {
    if (title === this.title) { return; }
    this.title = title;
    this.titleEl.textContent = title;
  };
  Window.prototype.resize = function (w, h) {
    this.width = w;
    this.height = h;
    // TODO: forward down to apps
  };
  Window.prototype.onClose = function (evt) {
    evt.preventDefault();
    this.parent.remove(this);
    refresh();
  };
  Window.prototype.onDrag = function (dx, dy) {
    var style = this.el.style;
    if (!this.dragging) {
      selectQuadrant(onWindowDrop);
      windowDragging = this;
      this.el.classList.add('moving');
      var empty = new Empty();
      this.dragging = empty;
      var rect = this.el.getBoundingClientRect();
      this.x = rect.left;
      this.y = rect.top;
      style.width = (rect.right - rect.left) + 'px';
      style.height = (rect.bottom - rect.top) + 'px';
      document.body.appendChild(this.el);
      this.parent.replace(this, empty);
      this.parent = null;
      refresh();
    }
    this.x += dx;
    this.y += dy;
    style.top = this.y + 'px';
    style.left = this.x + 'px';
  };
  Window.prototype.onMove = function (mx, my) {
    if (!hoverback || this.dragging) { return; }
    setHover(this);
    var rect = this.el.getBoundingClientRect();
    var x = (mx - rect.left) / (rect.right - rect.left),
        y = (my - rect.top) / (rect.bottom - rect.top);
    var quadrant = (x > (1 - y)) ?
      ((x > y) ? 'right' : 'bottom') :
      ((x > y) ? 'top' : 'left');
    if (quadrant === this.quadrant) { return; }
    this.quadrant = quadrant;
    var style = this.hoverEl.style;
    switch (quadrant) {
      case 'left':
        style.left = 0;
        style.right = 'auto';
        style.top = 0;
        style.bottom = 0;
        style.width = '50%';
        style.height = 'auto';
        break;
      case 'right':
        style.left = 'auto';
        style.right = 0;
        style.top = 0;
        style.bottom = 0;
        style.width = '50%';
        style.height = 'auto';
        break;
      case 'top':
        style.left = 0;
        style.right = 0;
        style.top = 0;
        style.bottom = 'auto';
        style.width = 'auto';
        style.height = '50%';
        break;
      case 'bottom':
        style.left = 0;
        style.right = 0;
        style.top = 'auto';
        style.bottom = 0;
        style.width = 'auto';
        style.height = '50%';
        break;
    }
  };
  Window.prototype.onClick = function (evt) {
    if (!hoverback) { return; }
    evt.preventDefault();
    doQuadrant();
  };
  Window.prototype.add = function (other) {
    var split;
    var parent = this.parent;
    switch (this.quadrant) {
      case 'top':
        split = new Split(other, this, true);
        break;
      case 'bottom':
        split = new Split(this, other, true);
        break;
      case 'left':
        split = new Split(other, this, false);
        break;
      case 'right':
        split = new Split(this, other, false);
        break;
    }
    parent.replace(this, split);

  };

  function Split(first, second, isVertical) {
    this.first = first;
    this.second = second;
    this.parent = parent;
    first.parent = this;
    second.parent = this;
    this.isVertical = isVertical;
    this.width = 0;
    this.height = 0;
    this.firstSize = 0;
    var orientation = isVertical ? 'vertical' : 'horizontal';
    domBuilder(['.cell.split.' + orientation + '$el',
      ['.first$firstEl', first.el],
      ['.second$secondEl', second.el],
      ['.slider$sliderEl', drag(this.onDrag.bind(this))],
    ], this);
  }

  Split.prototype.onDrag = function (dx, dy) {
    this.resize(this.width, this.height, this.firstSize +=
      this.isVertical ? dy : dx);
  };

  Split.prototype.resize = function (w, h, firstSize) {
    this.width = w;
    this.height = h;
    this.firstSize = firstSize === undefined ? (this.firstSize ?
      (this.firstSize /
        (this.isVertical ? this.height : this.width) *
        (this.isVertical ? h : w)) :
        (((this.isVertical ? h : w) - 10) / 2)) : firstSize;
    this.width = w;
    this.height = h;
    firstSize = Math.floor(this.firstSize);
    if (this.isVertical) {
      var height = Math.floor(this.height);
      this.firstEl.style.height = firstSize + 'px';
      this.secondEl.style.height = (height - 10 - firstSize) + 'px';
      this.sliderEl.style.top = firstSize + 'px';
      this.first.resize(this.width, this.firstSize);
      this.second.resize(this.width, this.height - 10 - this.firstSize);
    }
    else {
      var width = Math.floor(this.width);
      this.firstEl.style.width = firstSize + 'px';
      this.secondEl.style.width = (width - 10 - firstSize) + 'px';
      this.sliderEl.style.left = firstSize + 'px';
      this.first.resize(this.firstSize, this.height);
      this.second.resize(this.width - 10 - this.firstSize, this.height);
    }
  };
  Split.prototype.replace = function (oldChild, newChild) {
    newChild.parent = this;
    var parentEl;
    if (oldChild === this.first) {
      this.first = newChild;
      parentEl = this.firstEl;
    }
    else if (oldChild === this.second) {
      this.second = newChild;
      parentEl = this.secondEl;
    }
    if (oldChild.el.parentNode === parentEl) {
      parentEl.removeChild(oldChild.el);
    }
    parentEl.appendChild(newChild.el);
  };

  Split.prototype.remove = function (child) {
    if (child === this.first) {
      this.parent.replace(this, this.second);
    }
    else if (child === this.second) {
      this.parent.replace(this, this.first);
    }
  };

  function Desktop(child) {
    this.child = child;
    child.parent = this;
    domBuilder(['.desktop$el', child.el], this);
  }
  Desktop.prototype.resize = function (w, h) {
    console.log('resize', w, h);
    if (w && h) {
      this.width = w;
      this.height = h;
    }
    else {
      w = this.width;
      h = this.height;
    }
    if (this.child) {
      this.child.resize(w, h);
    }
  };
  Desktop.prototype.remove = function (child) {
    if (child.el.parentNode === this.el) {
      this.el.removeChild(child.el);
    }
    var empty = new Empty();
    this.child = empty;
    empty.parent = this;
    this.el.appendChild(empty.el);
  };
  Desktop.prototype.replace = function (oldChild, newChild) {
    var parentEl = this.el;
    if (oldChild.el.parentNode === parentEl) {
      parentEl.removeChild(oldChild.el);
    }
    parentEl.appendChild(newChild.el);
    newChild.parent = this;
    this.child = newChild;
  };

  Desktop.prototype.newWindow = function (title, callback) {
    selectQuadrant(function (err, slot) {
      if (err) { return callback(err); }
      var win = new Window(title);
      slot.add(win);
      callback(null, win);
      refresh();
    });
  };

  function Empty() {
    domBuilder(['.empty$el',
      ['.hover$hoverEl', {
        onclick: this.onClick.bind(this),
      }]
    ], this);
  }

  Empty.prototype.resize = function (w, h) {
    this.width = w;
    this.height = h;
  };

  Empty.prototype.onMove = function () {
    if (!hoverback) { return; }
    setHover(this);
    var style = this.hoverEl.style;
    style.left = 0;
    style.right = 0;
    style.top = 0;
    style.bottom = 0;
    style.width = 'auto';
    style.height = 'auto';
  };
  Empty.prototype.add = function (other) {
    this.parent.replace(this, other);
  };
  Empty.prototype.onClick = function () {
    if (!hoverback) { return; }
    var cb = hoverback;
    hoverback = null;
    cb(null, this);
    setHover(null);
  };

  var desktop = new Desktop(new Empty());

  window.addEventListener('resize', refresh);
  window.addEventListener('mousemove', onMouseMove);
  window.addEventListener('mouseup', onMouseUp);

  refresh();
  function refresh() {
    desktop.resize(window.innerWidth, window.innerHeight);
  }

  return desktop;
});
