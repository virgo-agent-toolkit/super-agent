// Simple, but powerful require system
(function () {
  'use strict';

  let defs = {};
  let mods = {};
  let pending = {};

  window.define = define;
  window.require = require;
  require.async = requireAsync;
  require.async('main', function(){});

  function define(name, fn) {
    console.log('Definition loaded for ' + name);
    defs[name] = fn;
    if (pending[name]) {
      let cb = pending[name];
      delete pending[name];
      scanDeps(fn.toString(), cb);
    }
  }

  function require(name) {
    if (name in mods) {
      return mods[name];
    }
    if (name in defs) {
      return (mods[name] = defs[name](require));
    }
    throw new Error('No such module: ' + name);
  }

  function requireAsync(name, cb) {
    if (!cb) { return requireAsync.bind(null, name); }
    loadDef(name, function () {
      cb(null, require(name));
    });
  }

  function scanDeps(js, cb) {
    let matches = js.match(/require\('[^']+'\)/g);
    let left = matches && matches.length;
    if (!left) { return cb(); }
    for (let i = 0, l = left; i < l; i++) {
      let name = matches[i].match(/'(.+)'/)[1];
      loadDef(name, decrement);
    }
    function decrement() {
      if (!--left) { cb(); }
    }
  }

  function loadDef(name, cb) {
    if (name in pending || name in defs) { return cb(); }
    let tag = document.createElement('script');
    tag.setAttribute('src', name + '.js');
    tag.setAttribute('charset', 'utf8');
    tag.setAttribute('async', 'async');
    pending[name] = function () {
      // document.head.removeChild(tag);
      return cb();
    };
    document.head.appendChild(tag);
  }
})();
