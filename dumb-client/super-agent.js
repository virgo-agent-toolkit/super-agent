/*jshint esversion: 6*/

SuperAgent = (function () {
  "use strict";

  var scripts = {};

  function noop($) {}

  function getCode(name, type) {
    var query = "script[name='" + name + "." + type + "'][type='application/super-agent']";
    var tag = document.querySelector(query);
    return tag && tag.textContent;
  }

  function SuperAgent(domContainer, agentUrl, name) {
    run(function* () {
      var call = yield* rpc(agentUrl, {});
      var klass = "Z" + (Math.random()* 0x100000000000000).toString(16);
      var scope = domContainer.tagName.toLowerCase() + "." + klass + " ";
      domContainer.setAttribute('class', klass);

      var script = scripts[name];
      if (!script) {
        // Register lua code with agent
        var lua = getCode(name, "lua");
        if (!lua) { throw new Error("Missing lua part of widget"); }
        if (!(yield* call("register", name, lua))) {
          throw new Error("Failed to register lua script in agent");
        }

        // Register css with browser
        var css = getCode(name, "css");
        if (css) {
          css = css.split(/\n/).map(function (line) {
            line = line.trim();
            if (!line) return line;
            console.log([line]);
            return scope + line;
          }).join("\n");
          var tag = document.createElement('style');
          tag.textContent = css;
          document.head.appendChild(tag);
        }

        // Remember JS for each instance.
        var js = getCode(name, "js");
        script = scripts[name] = js ?
          new Function("$", "domBuilder", "msgpack", "run", "call", js) :
          noop;
      }

      var $ = {};
      script($, domBuilder, msgpack, run, call);

      yield* call(name,
        update,
        register
      );

      function register(name, fn) {
        $[name] = fn;
      }

      function update(target, tree) {
        target = target ? $[target] : domContainer;
        if (tree) {
          target.appendChild(domBuilder(tree, $, wrapEvent));
        }
        else {
          target.textContent = "";
        }
      }

      function wrapEvent(type, fn) {
        if (typeof(fn) === "string") {
          return $[fn];
        }
        return function (evt) {
          // TODO: add data according to type
          fn();
        };
      }
    });
  }

  var domBuilder = function () {
    function domBuilder(json, refs, wrapEvent) {

      // Render strings as text nodes
      if (typeof json === 'string') {
        return document.createTextNode(json);
      }

      // Pass through html elements and text nodes as-is
      if (json instanceof HTMLElement || json instanceof window.Text) {
        return json;
      }

      // Stringify any other value types
      if (!Array.isArray(json)) {
        return document.createTextNode(json + '');
      }

      // Empty arrays are just empty fragments.
      if (!json.length) {
        return document.createDocumentFragment();
      }

      var node, first;
      for (var i = 0, l = json.length; i < l; i++) {
        var part = json[i];

        if (!node) {
          if (typeof part === 'string') {
            // Create a new dom node by parsing the tagline
            var tag = part.match(TAG_MATCH);
            tag = tag ? tag[0] : 'div';
            node = document.createElement(tag);
            first = true;
            var classes = part.match(CLASS_MATCH);
            if (classes) {
              node.setAttribute('class', classes.map(stripFirst).join(' '));
            }
            var id = part.match(ID_MATCH);
            if (id) {
              node.setAttribute('id', id[0].substr(1));
            }
            var ref = part.match(REF_MATCH);
            if (refs && ref) {
              refs[ref[0].substr(1)] = node;
            }
            continue;
          } else if (typeof part === 'function') {
            return domBuilder(part.apply(null, json.slice(i + 1)), refs);
          } else {
            node = document.createDocumentFragment();
          }
        }

        // Except the first item if it's an attribute object
        if (first && typeof part === 'object' && part.constructor === Object) {
          setAttrs(node, part, wrapEvent);
        } else {
          node.appendChild(domBuilder(part, refs, wrapEvent));
        }
        first = false;
      }
      return node;
    }

    function setAttrs(node, attrs, wrapEvent) {
      var keys = Object.keys(attrs);
      for (var i = 0, l = keys.length; i < l; i++) {
        var key = keys[i];
        var value = attrs[key];
        if (key === '$') {
          value(node);
        } else if (key === 'css' || key === 'style' && value.constructor === Object) {
          setStyle(node.style, value);
        } else if (key.substr(0, 2) === 'on') {
          var name = key.substr(2);
          if (wrapEvent) { value = wrapEvent(name, value); }
          node.addEventListener(name, value, false);
        } else if (typeof value === 'boolean') {
          if (value) { node.setAttribute(key, key); }
        } else {
          node.setAttribute(key, value);
        }
      }
    }

    function setStyle(style, attrs) {
      var keys = Object.keys(attrs);
      for (var i = 0, l = keys.length; i < l; i++) {
        var key = keys[i];
        style[key] = attrs[key];
      }
    }

    var CLASS_MATCH = /\.[^.#$]+/g,
        ID_MATCH = /#[^.#$]+/,
        REF_MATCH = /\$[^.#$]+/,
        TAG_MATCH = /^[^.#$]+/;

    function stripFirst(part) {
      return part.substr(1);
    }

    return domBuilder;

  }();

  var run = function () {
    return run;
    function run(generator, callback) {
      var iterator;
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

      var data = null, yielded = false;

      var next = callback ? nextSafe : nextPlain;

      next();
      check();

      function nextSafe(err, item) {
        var n;
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
        var cont = (err ? iterator.throw(err) : iterator.next(item)).value;
        if (cont) { start(cont); }
        yielded = true;
      }

      function start(cont) {
        // Pass in resume to continuables if one was yielded.
        if (typeof cont === 'function') { return cont(resume()); }
        // If an array of continuables is yielded, run in parallel
        if (Array.isArray(cont)) {
          for (var i = 0, l = cont.length; i < l; ++i) {
            if (typeof cont[i] !== 'function') { return; }
          }
          return parallel(cont, resume());
        }
        // Also run hash of continuables in parallel, but name results.
        if (typeof cont === 'object' && Object.getPrototypeOf(cont) === Object.prototype) {
          var keys = Object.keys(cont);
          for (var j = 0, l2 = keys.length; j < l2; ++j) {
            if (typeof cont[keys[j]] !== 'function') { return; }
          }
          return parallelNamed(keys, cont, resume());
        }
      }

      function resume() {
        var done = false;
        return function () {
          if (done) { return; }
          done = true;
          data = arguments;
          check();
        };
      }

      function check() {
        while (data && yielded) {
          var err = data[0];
          var item = data[1];
          data = null;
          yielded = false;
          next(err, item);
          yielded = true;
        }
      }

    }

    function parallel(array, callback) {
      var length = array.length;
      var left = length;
      var results = new Array(length);
      var done = false;
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
      var length = keys.length;
      var left = length;
      var results = {};
      var done = false;
      return keys.forEach(function (key) {
        var cont = obj[key];
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


  }();

  var msgpack = function () {
    var exports = {};

    exports.inspect = inspect;
    function inspect(buffer) {
      if (buffer === undefined) { return 'undefined'; }
      var view;
      var type;
      if (buffer instanceof ArrayBuffer) {
        type = 'ArrayBuffer';
        view = new DataView(buffer);
      }
      else if (buffer instanceof DataView) {
        type = 'DataView';
        view = buffer;
      }
      if (!view) { return JSON.stringify(buffer); }
      var bytes = [];
      for (var i = 0; i < buffer.byteLength; i++) {
        if (i > 20) {
          bytes.push('...');
          break;
        }
        var byte = view.getUint8(i).toString(16);
        if (byte.length === 1) { byte = '0' + byte; }
        bytes.push(byte);
      }
      return '<' + type + ' ' + bytes.join(' ') + '>';
    }

    // Encode string as utf8 into dataview at offset
    exports.utf8Write = utf8Write;
    function utf8Write(view, offset, string) {

      for(var i = 0, l = string.length; i < l; i++) {
        var codePoint = string.charCodeAt(i);

        // One byte of UTF-8
        if (codePoint < 0x80) {
          view.setUint8(offset++, codePoint >>> 0 & 0x7f | 0x00);
          continue;
        }

        // Two bytes of UTF-8
        if (codePoint < 0x800) {
          view.setUint8(offset++, codePoint >>> 6 & 0x1f | 0xc0);
          view.setUint8(offset++, codePoint >>> 0 & 0x3f | 0x80);
          continue;
        }

        // Three bytes of UTF-8.
        if (codePoint < 0x10000) {
          view.setUint8(offset++, codePoint >>> 12 & 0x0f | 0xe0);
          view.setUint8(offset++, codePoint >>> 6  & 0x3f | 0x80);
          view.setUint8(offset++, codePoint >>> 0  & 0x3f | 0x80);
          continue;
        }

        // Four bytes of UTF-8
        if (codePoint < 0x110000) {
          view.setUint8(offset++, codePoint >>> 18 & 0x07 | 0xf0);
          view.setUint8(offset++, codePoint >>> 12 & 0x3f | 0x80);
          view.setUint8(offset++, codePoint >>> 6  & 0x3f | 0x80);
          view.setUint8(offset++, codePoint >>> 0  & 0x3f | 0x80);
          continue;
        }
        throw new Error('bad codepoint ' + codePoint);
      }
    }

    exports.utf8Read = utf8Read;
    function utf8Read(view, offset, length) {
      var string = '';
      for (var i = offset, end = offset + length; i < end; i++) {
        var byte = view.getUint8(i);
        // One byte character
        if ((byte & 0x80) === 0x00) {
          string += String.fromCharCode(byte);
          continue;
        }
        // Two byte character
        if ((byte & 0xe0) === 0xc0) {
          string += String.fromCharCode(
            ((byte & 0x0f) << 6) |
            (view.getUint8(++i) & 0x3f)
          );
          continue;
        }
        // Three byte character
        if ((byte & 0xf0) === 0xe0) {
          string += String.fromCharCode(
            ((byte & 0x0f) << 12) |
            ((view.getUint8(++i) & 0x3f) << 6) |
            ((view.getUint8(++i) & 0x3f) << 0)
          );
          continue;
        }
        // Four byte character
        if ((byte & 0xf8) === 0xf0) {
          string += String.fromCharCode(
            ((byte & 0x07) << 18) |
            ((view.getUint8(++i) & 0x3f) << 12) |
            ((view.getUint8(++i) & 0x3f) << 6) |
            ((view.getUint8(++i) & 0x3f) << 0)
          );
          continue;
        }
        throw new Error('Invalid byte ' + byte.toString(16));
      }
      return string;
    }

    exports.utf8ByteCount = utf8ByteCount;
    function utf8ByteCount(string) {
      var count = 0;
      for(var i = 0, l = string.length; i < l; i++) {
        var codePoint = string.charCodeAt(i);
        if (codePoint < 0x80) {
          count += 1;
          continue;
        }
        if (codePoint < 0x800) {
          count += 2;
          continue;
        }
        if (codePoint < 0x10000) {
          count += 3;
          continue;
        }
        if (codePoint < 0x110000) {
          count += 4;
          continue;
        }
        throw new Error('bad codepoint ' + codePoint);
      }
      return count;
    }

    exports.encode = function (value) {
      var buffer = new ArrayBuffer(encodedSize(value));
      var view = new DataView(buffer);
      encode(value, view, 0);
      return buffer;
    };

    exports.decode = decode;

    // https://github.com/msgpack/msgpack/blob/master/spec.md
    // we reserve extension type 0x00 to encode javascript 'undefined'

    function Decoder(view, offset) {
      this.offset = offset || 0;
      this.view = view;
    }
    Decoder.prototype.map = function (length) {
      var value = {};
      for (var i = 0; i < length; i++) {
        var key = this.parse();
        value[key] = this.parse();
      }
      return value;
    };
    Decoder.prototype.bin = function (length) {
      console.log('length', length);
      var array = new Uint8Array(length);
      var source = new Uint8Array(this.view.buffer);
      array.set(source.slice(this.offset, this.offset + length), 0);
      this.offset += length;
      console.log(array);
      return array.buffer;
    };
    Decoder.prototype.str = function (length) {
      var value = utf8Read(this.view, this.offset, length);
      this.offset += length;
      return value;
    };
    Decoder.prototype.array = function (length) {
      var value = new Array(length);
      for (var i = 0; i < length; i++) {
        value[i] = this.parse();
      }
      return value;
    };
    Decoder.prototype.parse = function () {
      var type = this.view.getUint8(this.offset);
      var value, length;
      // FixStr
      if ((type & 0xe0) === 0xa0) {
        length = type & 0x1f;
        this.offset++;
        return this.str(length);
      }
      // FixMap
      if ((type & 0xf0) === 0x80) {
        length = type & 0x0f;
        this.offset++;
        return this.map(length);
      }
      // FixArray
      if ((type & 0xf0) === 0x90) {
        length = type & 0x0f;
        this.offset++;
        return this.array(length);
      }
      // Positive FixNum
      if ((type & 0x80) === 0x00) {
        this.offset++;
        return type;
      }
      // Negative Fixnum
      if ((type & 0xe0) === 0xe0) {
        value = this.view.getInt8(this.offset);
        this.offset++;
        return value;
      }
      switch (type) {
      // str 8
      case 0xd9:
        length = this.view.getUint8(this.offset + 1);
        this.offset += 2;
        return this.str(length);
      // str 16
      case 0xda:
        length = this.view.getUint16(this.offset + 1);
        this.offset += 3;
        return this.str(length);
      // str 32
      case 0xdb:
        length = this.view.getUint32(this.offset + 1);
        this.offset += 5;
        return this.str(length);
      // bin 8
      case 0xc4:
        length = this.view.getUint8(this.offset + 1);
        this.offset += 2;
        return this.bin(length);
      // bin 16
      case 0xc5:
        length = this.view.getUint16(this.offset + 1);
        this.offset += 3;
        return this.bin(length);
      // bin 32
      case 0xc6:
        length = this.view.getUint32(this.offset + 1);
        this.offset += 5;
        return this.bin(length);
      // nil
      case 0xc0:
        this.offset++;
        return null;
      // false
      case 0xc2:
        this.offset++;
        return false;
      // true
      case 0xc3:
        this.offset++;
        return true;
      // uint8
      case 0xcc:
        value = this.view.getUint8(this.offset + 1);
        this.offset += 2;
        return value;
      // uint 16
      case 0xcd:
        value = this.view.getUint16(this.offset + 1);
        this.offset += 3;
        return value;
      // uint 32
      case 0xce:
        value = this.view.getUint32(this.offset + 1);
        this.offset += 5;
        return value;
      // uint 64
      case 0xcf: {
        var high = this.view.getUint32(this.offset + 1);
        var low = this.view.getUint32(this.offset + 5);
        value = high*0x100000000 + low;
        this.offset += 9;
        return value;
      }
      // int 8
      case 0xd0:
        value = this.view.getInt8(this.offset + 1);
        this.offset += 2;
        return value;
      // int 16
      case 0xd1:
        value = this.view.getInt16(this.offset + 1);
        this.offset += 3;
        return value;
      // int 32
      case 0xd2:
        value = this.view.getInt32(this.offset + 1);
        this.offset += 5;
        return value;
      // int 64
      case 0xd3:
        var high2 = this.view.getInt32(this.offset + 1);
        var low2 = this.view.getUint32(this.offset + 5);
        value = high2*0x100000000 + low2;
        this.offset += 9;
        return value;
      // map 16
      case 0xde:
        length = this.view.getUint16(this.offset + 1);
        this.offset += 3;
        return this.map(length);
      // map 32
      case 0xdf:
        length = this.view.getUint32(this.offset + 1);
        this.offset += 5;
        return this.map(length);
      // array 16
      case 0xdc:
        length = this.view.getUint16(this.offset + 1);
        this.offset += 3;
        return this.array(length);
      // array 32
      case 0xdd:
        length = this.view.getUint32(this.offset + 1);
        this.offset += 5;
        return this.array(length);
      // float
      case 0xca:
        value = this.view.getFloat32(this.offset + 1);
        this.offset += 5;
        return value;
      // double
      case 0xcb:
        value = this.view.getFloat64(this.offset + 1);
        this.offset += 9;
        return value;
      }
      throw new Error('Unknown type 0x' + type.toString(16));
    };
    function decode(buffer) {
      var view = new DataView(buffer);
      var decoder = new Decoder(view);
      var value = decoder.parse();
      if (decoder.offset !== buffer.byteLength) {
        throw new Error((buffer.byteLength - decoder.offset) + ' trailing bytes');
      }
      return value;
    }

    function encode(value, view, offset) {
      var type = typeof value;

      // Strings Bytes
      if (type === 'string') {
        var length = utf8ByteCount(value);
        // fix str
        if (length < 0x20) {
          view.setUint8(offset, length | 0xa0);
          utf8Write(view, offset + 1, value);
          return 1 + length;
        }
        // str 8
        if (length < 0x100) {
          view.setUint8(offset, 0xd9);
          view.setUint8(offset + 1, length);
          utf8Write(view, offset + 2, value);
          return 2 + length;
        }
        // str 16
        if (length < 0x10000) {
          view.setUint8(offset, 0xda);
          view.setUint16(offset + 1, length);
          utf8Write(view, offset + 3, value);
          return 3 + length;
        }
        // str 32
        if (length < 0x100000000) {
          view.setUint8(offset, 0xdb);
          view.setUint32(offset + 1, length);
          utf8Write(view, offset + 5, value);
          return 5 + length;
        }
      }

      if (value instanceof ArrayBuffer) {
        var length2 = value.byteLength;
        // bin 8
        if (length2 < 0x100) {
          view.setUint8(offset, 0xc4);
          view.setUint8(offset + 1, length2);
          (new Uint8Array(view.buffer)).set(new Uint8Array(value), offset + 2);
          return 2 + length2;
        }
        // bin 16
        if (length2 < 0x10000) {
          view.setUint8(offset, 0xc5);
          view.setUint16(offset + 1, length2);
          (new Uint8Array(view.buffer)).set(new Uint8Array(value), offset + 3);
          return 3 + length2;
        }
        // bin 32
        if (length2 < 0x100000000) {
          view.setUint8(offset, 0xc6);
          view.setUint32(offset + 1, length2);
          (new Uint8Array(view.buffer)).set(new Uint8Array(value), offset + 5);
          return 5 + length2;
        }
      }

      if (type === 'number') {
        // Floating Point
        if ((value << 0) !== value) {
          view.setUint8(offset, 0xcb);
          view.setFloat64(offset + 1, value);
          return 9;
        }

        // Integers
        if (value >=0) {
          // positive fixnum
          if (value < 0x80) {
            view.setUint8(offset, value);
            return 1;
          }
          // uint 8
          if (value < 0x100) {
            view.setUint8(offset, 0xcc);
            view.setUint8(offset + 1, value);
            return 2;
          }
          // uint 16
          if (value < 0x10000) {
            view.setUint8(offset, 0xcd);
            view.setUint16(offset + 1, value);
            return 3;
          }
          // uint 32
          if (value < 0x100000000) {
            view.setUint8(offset, 0xce);
            view.setUint32(offset + 1, value);
            return 5;
          }
          throw new Error('Number too big 0x' + value.toString(16));
        }
        // negative fixnum
        if (value >= -0x20) {
          view.setInt8(offset, value);
          return 1;
        }
        // int 8
        if (value >= -0x80) {
          view.setUint8(offset, 0xd0);
          view.setInt8(offset + 1, value);
          return 2;
        }
        // int 16
        if (value >= -0x8000) {
          view.setUint8(offset, 0xd1);
          view.setInt16(offset + 1, value);
          return 3;
        }
        // int 32
        if (value >= -0x80000000) {
          view.setUint8(offset, 0xd2);
          view.setInt32(offset + 1, value);
          return 5;
        }
        throw new Error('Number too small -0x' + (-value).toString(16).substr(1));
      }

      // null
      if (value === null) {
        view.setUint8(offset, 0xc0);
        return 1;
      }

      // Boolean
      if (type === 'boolean') {
        view.setUint8(offset, value ? 0xc3 : 0xc2);
        return 1;
      }

      // Container Types
      if (type === 'object') {
        var length3, size = 0;
        var isArray = Array.isArray(value);
        var keys;

        if (isArray) {
          length3 = value.length;
        }
        else {
          keys = Object.keys(value);
          length3 = keys.length;
        }

        if (length3 < 0x10) {
          view.setUint8(offset, length3 | (isArray ? 0x90 : 0x80));
          size = 1;
        }
        else if (length3 < 0x10000) {
          view.setUint8(offset, isArray ? 0xdc : 0xde);
          view.setUint16(offset + 1, length3);
          size = 3;
        }
        else if (length3 < 0x100000000) {
          view.setUint8(offset, isArray ? 0xdd : 0xdf);
          view.setUint32(offset + 1, length3);
          size = 5;
        }

        if (isArray) {
          for (var i = 0; i < length3; i++) {
            size += encode(value[i], view, offset + size);
          }
        }
        else {
          for (var j = 0; j < length3; j++) {
            var key = keys[j];
            size += encode(key, view, offset + size);
            size += encode(value[key], view, offset + size);
          }
        }

        return size;
      }
      throw new Error('Cannot serialize type to msgpack: ' + type);
    }

    function encodedSize(value) {
      var type = typeof value;

      // Raw Bytes
      if (type === 'string') {
        var length = utf8ByteCount(value);
        if (length < 0x20) {
          return 1 + length;
        }
        if (length < 0x100) {
          return 2 + length;
        }
        if (length < 0x10000) {
          return 3 + length;
        }
        if (length < 0x100000000) {
          return 5 + length;
        }
      }

      if (value instanceof ArrayBuffer) {
        var length4 = value.byteLength;
        if (length4 < 0x100) {
          return 2 + length4;
        }
        if (length4 < 0x10000) {
          return 3 + length4;
        }
        if (length4 < 0x100000000) {
          return 5 + length4;
        }
      }

      if (type === 'number') {
        // Floating Point
        // double
        if (value << 0 !== value) { return 9; }

        // Integers
        if (value >=0) {
          // positive fixnum
          if (value < 0x80) { return 1; }
          // uint 8
          if (value < 0x100) { return 2; }
          // uint 16
          if (value < 0x10000) { return 3; }
          // uint 32
          if (value < 0x100000000) { return 5; }
          // uint 64
          if (value < 0x10000000000000000) { return 9; }
          throw new Error('Number too big 0x' + value.toString(16));
        }
        // negative fixnum
        if (value >= -0x20) { return 1; }
        // int 8
        if (value >= -0x80) { return 2; }
        // int 16
        if (value >= -0x8000) { return 3; }
        // int 32
        if (value >= -0x80000000) { return 5; }
        // int 64
        if (value >= -0x8000000000000000) { return 9; }

        throw new Error('Number too small -0x' + value.toString(16).substr(1));
      }

      // undefined
      if (type === 'undefined') { return 3; }

      // Boolean, null
      if (type === 'boolean' || value === null) { return 1; }

      // Container Types
      if (type === 'object') {
        var length6, size = 0;
        if (Array.isArray(value)) {
          length6 = value.length;
          for (var i = 0; i < length6; i++) {
            size += encodedSize(value[i]);
          }
        }
        else {
          var keys = Object.keys(value);
          length6 = keys.length;
          for (var k = 0; k < length6; k++) {
            var key = keys[k];
            size += encodedSize(key) + encodedSize(value[key]);
          }
        }
        if (length6 < 0x10) {
          return 1 + size;
        }
        if (length6 < 0x10000) {
          return 3 + size;
        }
        if (length6 < 0x100000000) {
          return 5 + size;
        }
        throw new Error('Array or object too long 0x' + length6.toString(16));
      }
      throw new Error('Unknown type ' + type);
    }

    return exports;

  }();

  var rpc = function () {

    return rpc;

    function* rpc(url, runCommand) {
      var socket = new WebSocket(url, ['schema-rpc']);
      socket.binaryType = 'arraybuffer';
      socket.onmessage = onMessage;

      var fns = {};
      var nextId = 1;
      var waiting = {};
      return yield function (callback) {
        socket.onopen = function () {
          callback(null, call);
        };
        socket.onerror = function () {
          callback('Connection error');
        };
      };

      function getId() {
        var id = nextId;
        while (fns[id] || waiting[id]) {
          id++;
        }
        nextId = id + 1;
        return id;
      }

      function onMessage(evt) {
        var message;
        if (typeof evt.data === 'string') {
          message = JSON.parse(evt.data);
        }
        else {
          message = msgpack.decode(evt.data);
        }
        console.log('<- ' + JSON.stringify(message));
        if (!(Array.isArray(message) && typeof message[0] === 'number')) {
          console.error('Invalid message from socket', message);
          return;
        }
        message = thaw(message);
        var id = message[0];
        if (id < 0) {
          id = -id;
          var callback = waiting[id];
          if (callback) {
            delete waiting[id];
            nextId = id;
            message[0] = null;
            return callback.apply(null, message);
          }
          var emitter = fns[id];
          if (emitter) {
            return emitter.apply(null, message.slice(1));
          }
          console.error('Unknown response id received', id);
          return;
        }
        if (id > 0) {
          return runCommand.apply(null, message.slice(1));
        }
        if (id === 0) {
          write(message);
          socket.close();
          return;
        }
      }

      function thaw(value) {
        var type = typeof value;
        if (!value || type !== 'object') { return value; }
        if (Array.isArray(value)) {
          return value.map(thaw);
        }
        if (value instanceof ArrayBuffer) {
          return new Uint8Array(value);
        }
        if (Object.getPrototypeOf(value) !== Object.prototype) {
          return value;
        }
        var keys = Object.keys(value);
        var l = keys.length;
        if (l === 1 && keys[0] === '') {
          var id = -value[''];
          return function (...args) {
            write([id, ...args]);
          };
        }
        var copy = {};
        for (var i = 0; i < l; ++i) {
          var key = keys[i];
          copy[key] = thaw(value[key]);
        }
        return copy;
      }

      function freeze(value) {
        var type = typeof value;
        if (type === 'function') {
          var id = getId();
          fns[id] = value;
          return {'': id};
        }
        if (!value || type !== 'object') { return value; }
        if (Array.isArray(value)) {
          return value.map(freeze);
        }
        if (value instanceof Uint8Array) {
          return value.buffer;
        }
        if (Object.getPrototypeOf(value) !== Object.prototype) {
          return value;
        }
        var copy = {};
        var keys = Object.keys(value);
        for (var i = 0, l = keys.length; i < l; ++i) {
          var key = keys[i];
          var item = value[key];
          if (item !== undefined) {
            copy[key] = freeze(item);
          }
        }
        return copy;
      }

      function write(message) {
        message = freeze(message);
        console.log('-> ' + JSON.stringify(message));
        socket.send(msgpack.encode(message));
      }

      function* call(name, ...args) {
        var id = getId();
        return yield function (callback) {
          write([id, name, ...args]);
          waiting[id] = function (err, ...args) {
            if (args.length === 0) {
              return callback(err);
            }
            else if (args.length === 1) {
              return callback(err, args[0]);
            }
            if (args.length > 1 && args[0] === null && args[1]) {
              throw new Error(args[1]);
            }
            return callback(err, args);
          };
        };
      }
    }
  }();

  return SuperAgent;
})();
