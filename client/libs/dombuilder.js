//////////////////////////////////////
//                                  //
// JS domBuilder Library            //
//                                  //
// Tim Caswell <tim@creationix.com> //
//                                  //
//////////////////////////////////////
define('libs/dombuilder', function () {
  'use strict';

  function domBuilder(json, refs) {

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

    let node, first;
    for (let i = 0, l = json.length; i < l; i++) {
      let part = json[i];

      if (!node) {
        if (typeof part === 'string') {
          // Create a new dom node by parsing the tagline
          let tag = part.match(TAG_MATCH);
          tag = tag ? tag[0] : 'div';
          node = document.createElement(tag);
          first = true;
          let classes = part.match(CLASS_MATCH);
          if (classes) {
            node.setAttribute('class', classes.map(stripFirst).join(' '));
          }
          let id = part.match(ID_MATCH);
          if (id) {
            node.setAttribute('id', id[0].substr(1));
          }
          let ref = part.match(REF_MATCH);
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
        setAttrs(node, part);
      } else {
        node.appendChild(domBuilder(part, refs));
      }
      first = false;
    }
    return node;
  }

  function setAttrs(node, attrs) {
    let keys = Object.keys(attrs);
    for (let i = 0, l = keys.length; i < l; i++) {
      let key = keys[i];
      let value = attrs[key];
      if (key === '$') {
        value(node);
      } else if (key === 'css' || key === 'style' && value.constructor === Object) {
        setStyle(node.style, value);
      } else if (key.substr(0, 2) === 'on') {
        node.addEventListener(key.substr(2), value, false);
      } else if (typeof value === 'boolean') {
        if (value) { node.setAttribute(key, key); }
      } else {
        node.setAttribute(key, value);
      }
    }
  }

  function setStyle(style, attrs) {
    let keys = Object.keys(attrs);
    for (let i = 0, l = keys.length; i < l; i++) {
      let key = keys[i];
      style[key] = attrs[key];
    }
  }

  let CLASS_MATCH = /\.[^.#$]+/g,
      ID_MATCH = /#[^.#$]+/,
      REF_MATCH = /\$[^.#$]+/,
      TAG_MATCH = /^[^.#$]+/;

  function stripFirst(part) {
    return part.substr(1);
  }

  return domBuilder;

});
