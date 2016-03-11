/*global rpc*/
/*global run*/
// /*global virtualDom*/
'use strict';

let url = 'ws://localhost:8000/request/fc1eb9f7-69f0-4079-9e74-25ffd091022a';

function* main() {
  let call = yield* rpc(url);
  let echo = yield* call('echo', function (...value) {
    console.log('Echo!', ...value);
  });
  echo(1, 2, 3);
  echo({name: 'Tim', age: 33});
  echo(new Uint8Array([1,2,3,4]));
}

run(main);
