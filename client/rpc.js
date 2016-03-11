'use strict';
/*global msgpack*/
window.rpc = rpc;
function* rpc(url) {
  let socket = new WebSocket(url, ['schema-rpc']);
  socket.binaryType = 'arraybuffer';
  socket.onmessage = onMessage;

  let fns = {};
  let nextId = 1;
  let waiting = {};
  return yield function (callback) {
    socket.onopen = function () {
      callback(null, call);
    };
    socket.onerror = function () {
      callback('Connection error');
    };
  };

  function onMessage(evt) {
    let message;
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
    let id = message[0];
    if (id < 0) {
      id = -id;
      let callback = waiting[id];
      if (callback) {
        delete waiting[id];
        message[0] = null;
        return callback.apply(null, message);
      }
      let emitter = fns[id];
      if (emitter) {
        return emitter.apply(null, message.slice(1));
      }
      console.error('Unknown response id received', id);
      return;
    }
    if (id > 0) {
      console.log('TODO: route request', id);
      return;
    }
    if (id === 0) {
      write(message);
      socket.close();
      return;
    }
  }

  function thaw(value) {
    let type = typeof value;
    if (!value || type !== 'object') { return value; }
    if (Array.isArray(value)) {
      return value.map(thaw);
    }
    let keys = Object.keys(value);
    let l = keys.length;
    if (l === 1 && keys[0] === '') {
      let id = -value[''];
      return function (...args) {
        write([id, ...args]);
      };
    }
    let copy = {};
    for (let i = 0; i < l; ++i) {
      let key = keys[i];
      copy[key] = thaw(value[key]);
    }
    return copy;
  }

  function freeze(value) {
    let type = typeof value;
    if (type === 'function') {
      let id = nextId++;
      fns[id] = value;
      return {'': id};
    }
    if (!value || type !== 'object') { return value; }
    if (Array.isArray(value)) {
      return value.map(freeze);
    }
    let copy = {};
    let keys = Object.keys(value);
    for (let i = 0, l = keys.length; i < l; ++i) {
      let key = keys[i];
      copy[key] = freeze(value[key]);
    }
    return copy;
  }

  function write(message) {
    message = freeze(message);
    console.log('-> ' + JSON.stringify(message));
    socket.send(msgpack.encode(message));
  }

  function* call(name, ...args) {
    let id = nextId++;
    return yield function (callback) {
      write([id, name, ...args]);
      waiting[id] = callback;
    };
  }
}
