/*global rpc*/
/*global run*/
/*global Terminal*/
// /*global virtualDom*/
'use strict';

let agentId = 'fc1eb9f7-69f0-4079-9e74-25ffd091022a';
let url = 'ws://localhost:8000/request/' + agentId;
run(main);

function* main() {
  let call = yield* rpc(url);
  let echo = yield* call('echo', function (...value) {
    console.log('Echo!', ...value);
  });
  echo(1, 2, 3);
  echo({name: 'Tim', age: 33});
  echo(new Uint8Array([1,2,3,4]));
  echo({data:new Uint8Array([1,2,3,4]),fancy:true,bad:false});

  let [write, kill, resize] = yield* call('pty',
    '/bin/bash',
    [80,24],
    {},
    function onData(chunk) {
      if (chunk !== undefined) {
        term.write(chunk);
      }
      else {
        console.log('Pty stream closed');
        kill(8);
      }
    },
    function onError(error) {
      console.error(error);
    },
    function onExit(code, signal) {
      console.log('child exited', code, signal);
    }
  );
  let term = new Terminal({
    cols: 80,
    rows: 24,
    screenKeys: true
  });

  term.on('data', write);

  term.on('title', function(title) {
    document.title = title;
  });

  document.body.textContent = '';
  term.open(document.body);

  term.write('\x1b[31mWelcome to term.js!\x1b[m\r\n');

}
