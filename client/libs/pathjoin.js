define('libs/pathjoin', function () {
  'use strict';

  return pathJoin;

  function getPrefix(path) {
    var match = path.match(/^\//);
    return match && match[0];
  }

  function splitPath(path) {
    return path.split('/');
  }

  function joinParts(prefix, parts) {
    var path = parts.join('/');
    if (prefix) {
      path = prefix + path;
    }
    return path;
  }

  function pathJoin(...inputs) {
    var l = inputs.length;

    // Find the last segment that is an absolute path
    // Or if all are relative, prefix will be undefined.
    var prefix, i = l;
    while (i && !prefix) {
      prefix = getPrefix(inputs[--i]);
    }

    // If there was one, remove its prefix from its segment
    if (prefix) {
      inputs[i] = inputs[i].substr(prefix.length);
    }

    // Split all the paths segments into one large list
    var parts = [];
    while (i < l) {
      parts = parts.concat(splitPath(inputs[i++]));
    }

    // Evaluate special segments in reverse order.
    var skip = 0;
    var reversed = [];
    for (var idx = parts.length - 1; idx >= 0; idx--) {
      var part = parts[idx];
      if (part === '.') { continue; }
      if (part === '..') { skip++; }
      else if (skip > 0) { skip--; }
      else {
        reversed.push(part);
      }
    }

    // Reverse the list again to get the correct order
    parts = reversed.reverse();


    return joinParts(prefix, parts);
  }
});
