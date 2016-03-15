// Simple, but powerful require system
(function () {
  'use strict';
  let defs = {};
  let mods = {};
  let pending = {};
  window.define = function define(name, fn) {
    defs[name] = fn;
    console.log('defining', name);
    if (pending[name]) {
      let cb = pending[name];
      delete pending[name];
      scanDeps(fn.toString(), cb);
    }
  };

  window.require = require;
  require.async = requireAsync;

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
    if (name in defs) {
      return onDefined();
    }
    loadDef(name, onDefined);

    function onDefined() {
      cb(null, require(name));
    }
  }

  function scanDeps(js, cb) {
    let matches = js.match(/require\('[^']+'\)/g);
    if (!matches) { return cb(); }
    let left = matches.length;
    for (let i = 0, l = left; i < l)
    function getNext() {
      if (!matches.length) { return cb(); }
      let name = matches.pop().match(/'(.+)'/)[1];
      if (name in defs) { return getNext(); }
      loadDef(name, getNext);
    }
    getNext();
  }

  function loadDef(name, cb) {
    console.log('loading def', name);
    let tag = document.createElement('script');
    tag.setAttribute('async', true);
    tag.setAttribute('src', name + '.js');
    document.head.appendChild(tag);
    pending[name] = function () {
      document.head.removeChild(tag);
      console.log('loaded', name);
      return cb();
    };
  }
})();

window.onload = function () {
  'use strict';
  let require = window.require;
  require.async('libs/run', function (err, run) {
    run(function* () {
      let rpc = yield require.async('libs/rpc');
      console.log(rpc);
    }, function (err) {
      if (err) { throw err; }
    });
  });
};
