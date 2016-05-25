var mimes = {
  lua: 'text/x-lua',
  css: 'text/css',
  js: 'application/javascript',
};

var values = window.localStorage;

editor("lua");
editor("js");
editor("css");
run();

function editor(id) {
  var container = document.getElementById(id);
  var options = {
    value: values[id] || "",
    mode: mimes[id],
    theme: 'material',
    keyMap: 'sublime',
    lineNumbers: true,
    rulers: [{ column: 80 }],
    autoCloseBrackets: true,
    matchBrackets: true,
    showCursorWhenSelecting: true,
    styleActiveLine: true,
  };
  if (id === 'js') {
    options.lint = true;
    options.gutters = ["CodeMirror-lint-markers"];
  }

  var cm = new CodeMirror(container, options);
  cm.on('change', function () {
    values[id] = cm.getDoc().getValue();
  });
  window.addEventListener('resize', function () {
    cm.refresh();
  });
  setTimeout(function () {
    cm.refresh();
  }, 0);
}


function run() {
  var domContainer = document.getElementById("target");

  var options = {
    css: values.css,
    js: values.js,
    lua: values.lua || ""
  };
  var search = window.location.search;
  if (search) {
    search = search.replace(/^\?/, '');
    search.split("&").forEach(function (prop) {
      var pair = prop.split("=");
      options[pair[0]] = pair[1];
    });
  }
  if (!options.agent) {
    options.agent = "ws://localhost:7000/";
  }
  if (options.gist) {
    var req = new XMLHttpRequest();
    req.open("GET", "https://api.github.com/gists/" + options.gist);
    req.onload = onLoad;
    return req.send();
  }

  function onLoad(evt) {
    var files = JSON.parse(req.responseText).files;
    values.css = files["css.css"] && files["css.css"].content;
    values.js = files["js.js"] && files["js.js"].content;
    values.lua = files["lua.lua"] && files["lua.lua"].content;
    window.location.search = "?agent=" + options.agent;
  }


  SuperAgent(domContainer, options);
}
