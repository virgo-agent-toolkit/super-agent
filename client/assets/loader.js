// Simple, but powerful require system
(function () {
  'use strict';

  var defs = {};
  var mods = {};
  var pending = {};

  window.define = define;
  window.require = require;
  require.loadDefs = loadDefs;
  require.async = requireAsync;
  return bootstrap();

  function bootstrap() {
    var tag = document.querySelector('script[bootloader]');
    if (!tag) { return; }
    document.head.removeChild(tag);
    var prefetch = tag.getAttribute('prefetch');
    var main = tag.getAttribute('main');
    if (!main) { main = 'main'; }
    var deps = prefetch ? prefetch.split(/ *, */) : [];
    loadDefs(deps, function () {
      require.async(main, function () {
        console.log('Main bootstrapped');
      });
    });
  }

  function define(name, fn) {
    defs[name] = fn;
    if (pending[name]) {
      var cb = pending[name];
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

  function scanDeps(js, cb) {
    var matches = js.match(/require\('[^']+'\)/g);
    if (!matches) { return cb(); }
    return loadDefs(matches.map(function (match) {
      return match.match(/'(.+)'/)[1];
    }), cb);
  }

  function loadDefs(names, cb) {
    names = names.filter(function (name) {
      return !((name in pending) || (name in defs));
    });
    var left = names.length;
    if (!left) { return cb(); }
    for (var i = 0, l = left; i < l; i++) {
      loadDef(names[i], decrement);
    }
    function decrement() {
      if (!--left) { cb(); }
    }
  }

  function requireAsync(name, cb) {
    return loadDefs([name], function () {
      return cb(null, require(name));
    });
  }

  function loadDef(name, cb) {
    if ((name in pending) || (name in defs)) { return cb(); }
    var tag = document.createElement('script');
    tag.setAttribute('src', name + '.js');
    tag.setAttribute('charset', 'utf8');
    tag.setAttribute('async', 'async');
    pending[name] = function () {
      document.head.removeChild(tag);
      return cb();
    };
    document.head.appendChild(tag);
  }
})();
