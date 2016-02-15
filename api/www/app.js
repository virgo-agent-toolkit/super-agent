"use strict";

// Tiny reactive framework in elm style.
function app(initialModel, renderView, updateModel) {
  var virtualDom = window.virtualDom;
  var h = virtualDom.h;
  var diff = virtualDom.diff;
  var patch = virtualDom.patch;
  var createElement = virtualDom.create;
  var model = initialModel;
  var tree, rootNode;
  tree = renderView(emit, h, model);
  rootNode = createElement(tree);
  document.body.appendChild(rootNode);
  emit("query", "aep", {})();
  function emit() {
    var action = Array.prototype.slice.call(arguments);
    return function () {
      for (var i = 0, l= arguments.length; i < l; i++) {
        action.push(arguments[i]);
      }
      return window.requestAnimationFrame(function () {
        var args = [emit, model, action]
        model = updateModel.apply(null, args);
        var newTree = renderView(emit, h, model);
        var patches = diff(tree, newTree);
        rootNode = patch(rootNode, patches);
        tree = newTree;
      });
    };
  }
}

app({}, view, update);

var names = {
  aep: "Agent Endpoint",
  id: "ID",
  hostname: "Hostname"
}

function renderQueryResults(emit, h, model) {
  return h("div", [
    h(".nav", [
      h("h1", names[model.table])
    ]),
    model.columns ?
    h("table", [
      h("thead", [
        h("tr",
          model.columns.map(function (field) {
            return h("th", names[field]);
          }).concat([
            h("th", "Actions")
          ])
        )
      ]),
      h("tbody", model.rows.map(function (row) {
        return h("tr",
          row.map(function (cell) {
            return h("td", cell);
          }).concat([
            h("td", [
              h("button", {onclick:emit("view",model.table,row[0])}, "View"),
              h("button", {onclick:emit("delete",model.table,row[0])}, "Delete"),
            ])
          ])
        )
      }))
    ]) : h(".loading", "Loading...")
  ]);
}

function view(emit, h, model) {
  if (!model.mode) {
    return h(".loading", "Loading...");
  }
  if (model.mode === "query") {
    return renderQueryResults(emit, h, model);
  }
  if (mode.mode === "read") {

  }
  throw new Error("Unknown mode: " + model.mode);
}

function update(emit, model, args) {
  console.log("Update", args)
  var action = args[0];
  if (action === "query") {
    var table = args[1];
    var query = args[2];
    call(table + ".query", [query], emit("query-result"));
    return {
      mode: "query",
      table: table,
    }
  }
  if (action === "query-result") {
    var err = args[1];
    if (err) {
      model.error = err;
      return model;
    }
    var result = args[2];
    model.columns = result[0];
    model.rows = result[1];
    model.stats = result[2];
    return model;
  }
  if (action === "view") {
    var table = args[1];
    var id = args[2];
    call(table + ".read", [id], emit("read-result"));
    return {
      mode: "view",
      table: table
    };
  }
  throw new Error("Unknown action: " + action);
}

var rpc;
function call(name, args, callback) {
  if (rpc) { onConnect(null, rpc); }
  else { client(onConnect); }

  function onConnect(err, socket) {
    rpc = socket;
    socket.call(name, args, callback);
  }
}
function client(callback) {
  var url = window.location.protocol.toString().replace(/^http/, 'ws') +
    "//" + window.location.host + "/websocket";
  var ws = new WebSocket(url, ["schema-rpc"]);
  function send(args) {
    var message = Array.prototype.slice.call(args);
    console.log("->", message);
    return ws.send(JSON.stringify(message));
  }
  ws.onopen = function () {
    var rpc = {};
    var waiting = {};
    var nextId = 1;
    rpc.call = function (name, args, cb) {
      var id = nextId++;
      waiting[id] = cb;
      send([id, name].concat(args));
    };
    ws.onmessage = function (evt) {
      var data = evt.data;
      var message = JSON.parse(data);
      console.log("<-", message);
      var id = message[0];
      if (id < 0) {
        id = -id;
        var cb = waiting[id];
        delete waiting[id];
        cb(message[2], message[1]);
      }
    }
    delete ws.onopen;
    delete ws.onerror;
    return callback(null, rpc);
  }
  ws.onerror = function () {
    delete ws.onopen;
    delete ws.onerror;
    return callback("Problem connecting");
  }
}
