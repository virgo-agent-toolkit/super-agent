/*global rpc,run*/
'use strict';

window.RaxClient = (function () {
  let agentId = 'fc1eb9f7-69f0-4079-9e74-25ffd091022a';
  let url = 'ws://localhost:8000/request/' + agentId;
  let applications = {};
  let call;
  window.onload = function () { run(main); };

  return {
    registerApp: registerApp,
    call: onRequest,
  };

  function onRequest(name, ...args) {
    let app = applications[name];
    if (!app) {
      throw new Error('No such application: ' + name);
    }
    function update(vdom) {
      console.log("TODO: update vdom");
      console.log(vdom);
    }
    run(function* () {
      yield* app(call, update, ...args);
    });
  }

  function registerApp(name, init) {
    applications[name] = init;
  }

  function* main() {
    call = yield* rpc(url, onRequest);
  }
})();
