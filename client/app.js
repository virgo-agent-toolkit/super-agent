/*global msgpack*/
/*global run*/
// /*global virtualDom*/
'use strict';

let aepPrefix = 'ws://localhost:8000/request/';

function getAgent(id) { return function (callback) {
  let socket = new WebSocket(aepPrefix + id, ['schema-rpc']);
  socket.binaryType = 'arraybuffer';
  socket.onopen = function () {
    callback(null, call);
  };

  let fns = {};
  let nextId = 1;
  let waiting = {};

  socket.onmessage = function (evt) {
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
  };

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

  function call(name, ...args) { return function (callback) {
    let id = nextId++;
    write([id, name, ...args]);
    waiting[id] = callback;
  };}
};}

function* main() {
  let call = yield getAgent('fc1eb9f7-69f0-4079-9e74-25ffd091022a');
  let echo = yield call('echo', function (...value) {
    console.log('Echo!', ...value);
  });
  echo(1, 2, 3);
  echo({name: 'Tim', age: 33});

}

run(main);
