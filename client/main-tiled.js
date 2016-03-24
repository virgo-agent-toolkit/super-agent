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
  var run = require('libs/run');
  var rpc = require('libs/rpc');
  var domBuilder = require('libs/dombuilder');
  var drag = require('libs/drag-helper');

  function Split(parent, first, second, isVertical) {
    this.first = first;
    this.second = second;
    this.parent = parent;
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
    console.log(dx, dy);
    this.resize(this.width, this.height, this.firstSize +=
      this.isVertical ? dy : dx);
  };

  Split.prototype.resize = function (w, h, firstSize) {
    // if (w === this.width && h === this.height &&
    //     (firstSize === undefined || firstSize === this.firstSize)) {
    //   return;
    // }

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

  function Window(title) {
    this.title = title;
    domBuilder(['.cell.window$el',
      ['.title$titleEl', title],
      ['.container$containerEl'],
    ], this);
  }
  Window.prototype.setTitle = function (title) {
    if (title === this.title) { return; }
    this.title = title;
    this.titleEl.textContent = title;
  };
  Window.prototype.resize = function (w, h) {
    // TODO: forward down to apps
  };

  run(function* () {
    var call = yield* rpc();
    console.log(call);
    console.log();
    document.body.textContent = '';
    var a = new Window('Window A');
    var b = new Window('Window B');
    var c = new Window('Window C');
    var d = new Window('Window D');
    var e = new Split(null, a, b, true);
    var f = new Split(null, c, d, true);
    var g = new Split(null, e, f, false);
    window.onresize = onResize;
    onResize();
    document.body.appendChild(g.el);
    function onResize() {
      g.resize(window.innerWidth, window.innerHeight);
    }
  });

});
