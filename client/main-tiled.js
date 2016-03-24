/*
  Cell is Split or Window

  Split
  - el: Root Element
  - first: Cell
  - second: Cell
  - parent: Cell
  - width: Int
  - height: Int
  - orientation: "vertical" or "horizontal"
  - split: Int

  Window
  - el: Root Element
  - title: Element
  - body: Element


*/
define('main-tiled', function (require) {
  'use strict';
  // var run = require('libs/run');
  // var rpc = require('libs/rpc');
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

  var hoverback = null;
  function selectQuadrant(callback) {
    if (hoverback) {
      throw new Error('already in hover select mode');
    }
    hoverback = callback;
  }

  function Window(title) {
    this.title = title;
    this.width = 0;
    this.height = 0;
    domBuilder(['.cell.window$el',
      { onmousemove: this.onMove.bind(this) },
      ['.title$titleEl',
        drag(this.onDrag.bind(this)),
        title],
      ['.close$closeEl',
        { onclick: this.onClose.bind(this) },
        '✖'],
      ['.content$contentEl',
        ['button',
          { onclick: addWindow },
          'New Window']],
      ['.hover$hoverEl',
        { onclick: this.onClick.bind(this) }],
    ], this);
  }
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
    onResize();
  };
  Window.prototype.onDrag = function (dx, dy) {
    var style = this.el.style;
    if (!this.dragging) {
      selectQuadrant(function (err, win) {
        win.add(self);
        self.dragging.parent.remove(self.dragging);
        self.dragging = null;
        self.el.classList.remove('moving');
        self.el.setAttribute('style', '');
        onResize();
      });
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
      var self = this;
    }
    this.x += dx;
    this.y += dy;
    style.top = this.y + 'px';
    style.left = this.x + 'px';
  };
  Window.prototype.onMove = function (evt) {
    if (!hoverback || this.dragging) { return; }
    setHover(this);
    var rect = this.el.getBoundingClientRect();
    var x = (evt.pageX - rect.left) / (rect.right - rect.left),
        y = (evt.pageY - rect.top) / (rect.bottom - rect.top);
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
  Window.prototype.onClick = function () {
    if (!hoverback) { return; }
    var cb = hoverback;
    hoverback = null;
    cb(null, this);
    setHover(null);
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
    newChild.parent = this;
  };

  Split.prototype.remove = function (child) {
    var other;
    if (child === this.first) {
      other = this.second;
    }
    else if (child === this.second) {
      other = this.first;
    }
    if (other) {
      this.parent.replace(this, other);
    }
  };

  function Desktop(child) {
    this.child = child;
    child.parent = this;
    domBuilder(['.desktop$el', child.el], this);
  }
  Desktop.prototype.resize = function (w, h) {
    this.width = w;
    this.height = h;
    if (this.child) {
      this.child.resize(w, h);
    }
  };
  Desktop.prototype.remove = function (child) {
    this.el.removeChild(child.el);
    this.child = null;
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

  function Empty() {
    domBuilder(['.empty$el',
      { onmousemove: this.onMove.bind(this) },
      ['.hover$hoverEl', {
        onclick: this.onClick.bind(this),
      }]
    ], this);
  }

  Empty.prototype.resize = function () {};

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


  // run(function* () {
    // var call = yield* rpc();
    // console.log(call);
  // });

  document.body.textContent = '';
  var a = new Window('Window A');
  var b = new Window('Window B');
  var s = new Split(a, b, false);
  var d = new Desktop(s);
  window.onresize = onResize;
  onResize();
  document.body.appendChild(d.el);
  function onResize() {
    d.resize(window.innerWidth, window.innerHeight);
  }

  var next = 'C'.charCodeAt(0);
  function addWindow() {
    selectQuadrant(function (err, win) {
      win.add(new Window('Window ' + String.fromCharCode(next++)));
      onResize();
    });
  }

});
