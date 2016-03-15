define('libs/run', function () {
  'use strict';
  return run;
  function run(generator, callback) {
    let iterator;
    if (typeof generator === 'function') {
      // Pass in resume for no-wrap function calls
      iterator = generator(resume);
    }
    else if (typeof generator === 'object') {
      // Oterwise, assume they gave us the iterator directly.
      iterator = generator;
    }
    else {
      throw new TypeError('Expected generator or iterator and got ' + typeof generator);
    }

    let data = null, yielded = false;

    let next = callback ? nextSafe : nextPlain;

    next();
    check();

    function nextSafe(err, item) {
      let n;
      try {
        n = (err ? iterator.throw(err) : iterator.next(item));
        if (!n.done) {
          if (n.value) { start(n.value); }
          yielded = true;
          return;
        }
      }
      catch (excp) {
        return callback(excp);
      }
      return callback(null, n.value);
    }

    function nextPlain(err, item) {
      let cont = (err ? iterator.throw(err) : iterator.next(item)).value;
      if (cont) { start(cont); }
      yielded = true;
    }

    function start(cont) {
      // Pass in resume to continuables if one was yielded.
      if (typeof cont === 'function') { return cont(resume()); }
      // If an array of continuables is yielded, run in parallel
      if (Array.isArray(cont)) {
        for (let i = 0, l = cont.length; i < l; ++i) {
          if (typeof cont[i] !== 'function') { return; }
        }
        return parallel(cont, resume());
      }
      // Also run hash of continuables in parallel, but name results.
      if (typeof cont === 'object' && Object.getPrototypeOf(cont) === Object.prototype) {
        let keys = Object.keys(cont);
        for (let i = 0, l = keys.length; i < l; ++i) {
          if (typeof cont[keys[i]] !== 'function') { return; }
        }
        return parallelNamed(keys, cont, resume());
      }
    }

    function resume() {
      let done = false;
      return function () {
        if (done) { return; }
        done = true;
        data = arguments;
        check();
      };
    }

    function check() {
      while (data && yielded) {
        let err = data[0];
        let item = data[1];
        data = null;
        yielded = false;
        next(err, item);
        yielded = true;
      }
    }

  }

  function parallel(array, callback) {
    let length = array.length;
    let left = length;
    let results = new Array(length);
    let done = false;
    return array.forEach(function (cont, i) {
      cont(function (err, result) {
        if (done) { return; }
        if (err) {
          done = true;
          return callback(err);
        }
        results[i] = result;
        if (--left) { return; }
        done = true;
        return callback(null, results);
      });
    });
  }

  function parallelNamed(keys, obj, callback) {
    let length = keys.length;
    let left = length;
    let results = {};
    let done = false;
    return keys.forEach(function (key) {
      let cont = obj[key];
      results[key] = null;
      cont(function (err, result) {
        if (done) { return; }
        if (err) {
          done = true;
          return callback(err);
        }
        results[key] = result;
        if (--left) { return; }
        done = true;
        return callback(null, results);
      });
    });
  }
});
