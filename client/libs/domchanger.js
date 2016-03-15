/*
Design of internal tree used for diffing algorithm:
==================================================

- collection of nodes is object with keys being unique name of node.
- items can be component, text node, tag node, or raw element:
  - text nodes contain {text, el} (el is only when instanced)
  - tag nodes contain {tagName, el, props, children} (el is only when instaced)
  - raw elements simply contain {el}
  - components in the new tree contain {component, data}, but once instanced
    contain {append, destroy, handleEvent, update} or the component instance itself.

Unique Name Algorithm:
=====================

Unique names are given to each node so that we can track their movement and
be smart about reusing nodes when changes happen.

- Names are only unique to their parent node, not globally.
- Components are named by their constructor name and optional user provided key
- Elements are named by their tag name and optional user provided ref
- Text nodes are simply named 'text' and raw nodes are 'el'.
- When a duplicate name happens, the second one gets '-2' appended, then '-3'
  and so on.
*/

define('libs/domchanger', function () {
  'use strict';

  function forEach(obj, fn) {
    let keys = Object.keys(obj);
    for (let i = 0, l = keys.length; i < l; ++i) {
      let key = keys[i];
      fn(key, obj[key]);
    }
  }

  function createComponent(component, parent, owner) {
    let refs = {};
    let data = [];
    let roots = {};
    // console.log('new ' + component.name);
    let out = component(emit, refresh, refs);
    let render = out.render;
    let on = out.on || {};
    let cleanup = out.cleanup || noop;
    let afterRefresh = out.afterRefresh || noop;
    let instance = {
      update: update,
      destroy: destroy,
      append: append,
      handleEvent: handleEvent
    };

    // Add comment for this component.
    let comment = document.createComment(component.name);
    parent.appendChild(comment);

    return instance;

    function append() {
      comment.parentNode.appendChild(comment);
      forEach(roots, function (key, node) {
        if (node.el) { parent.appendChild(node.el); }
        else if (node.append) { node.append(); }
      });
    }

    function destroy() {
      // console.log('destroy', component.name);
      comment.parentNode.removeChild(comment);
      comment = null;
      cleanRoots(roots);
      delete instance.update;
      delete instance.destroy;
      delete instance.handleEvent;
      cleanup();
    }

    function cleanRoots(roots) {
      forEach(roots, function (key, node) {
        if (node.el) { node.el.parentNode.removeChild(node.el); }
        else if (node.destroy) { node.destroy(); }
        delete roots[key];
        if (node.children) { cleanRoots(node.children); }
      });
    }

    function refresh() {
      if (!render) { return; }
      let tree = nameNodes(render.apply(null, data));
      apply(parent, tree, roots);
      afterRefresh();
    }

    function removeItem(item) {
      if (item.destroy) { item.destroy(); }
      else { item.el.parentNode.removeChild(item.el); }
    }

    function apply(top, newTree, oldTree) {

      // Delete any items that don't exist in the new tree
      forEach(oldTree, function (key, item) {
        if (!newTree[key]) {
          removeItem(item);
          delete oldTree[key];
          // console.log('removed ' + key)
        }
      });

      let oldKeys = Object.keys(oldTree);
      let newKeys = Object.keys(newTree);
      let index, length, key;
      for (index = 0, length = newKeys.length; index < length; index++) {
        key = newKeys[index];
        // console.group(key);
        let item = oldTree[key];
        let newItem = newTree[key];

        // Handle text nodes
        if ('text' in newItem) {
          if (item) {
            // Update the text if it's changed.
            if (newItem.text !== item.text) {
              item.el.nodeValue = item.text = newItem.text;
              // console.log('updated')
            }
          }
          else {
            // Otherwise create a new text node.
            item = oldTree[key] = {
              text: newItem.text,
              el: document.createTextNode(newItem.text)
            };
            top.appendChild(item.el);
            // console.log('created')
          }
        }

        // Handle tag nodes
        else if (newItem.tagName) {
          // Create a new item if there isn't one
          if (!item) {
            item = oldTree[key] = {
              tagName: newItem.tagName,
              el: document.createElement(newItem.tagName),
              children: {}
            };
            if (newItem.ref) {
              item.ref = newItem.ref;
              refs[item.ref] = item.el;
            }
            top.appendChild(item.el);
            // console.log('created')
          }
          // Update the tag
          if (!item.props) { item.props = {}; }
          updateAttrs(item.el, newItem.props, item.props);

          if (newItem.children) {
            apply(item.el, newItem.children, item.children);
          }
        }

        // Handle component nodes
        else if (newItem.component) {
          if (!item) {
            item = oldTree[key] = createComponent(newItem.component, top, instance);
            item.append();
            // console.log('created')
          }
          item.update.apply(null, newItem.data);
        }

        else if (newItem.el) {
          if (item) {
            item = removeItem(item);
          }
          item = oldTree[key] = {
            el: newItem.el
          };
          top.appendChild(item.el);
        }

        else {
          console.error(newItem);
          throw new Error('This shouldn\'t happen');
        }

        // console.groupEnd(key);
      }

      // Check to see if set needs re-ordering
      let needOrder = false;
      for (index = 0, length = newKeys.length; index < length; index++) {
        key = newKeys[index];
        let oldIndex = oldKeys.indexOf(key);
        if (oldIndex >= 0 && oldIndex !== index) {
          needOrder = true;
          break;
        }
      }

      // If it does, sort the set and virtual tree to match the new order
      if (needOrder) {
        forEach(newTree, function (key) {
          let item = oldTree[key];
          delete oldTree[key];
          oldTree[key] = item;
          if (item.append) { item.append(); }
          else { top.appendChild(item.el); }
        });
        // console.log('reordered')
      }

    }

    function update() {
      data = slice.call(arguments);
      refresh();
    }

    function emit() {
      if (!owner) { throw new Error('Can\'t emit events from top-level component'); }
      owner.handleEvent.apply(null, arguments);
    }

    function handleEvent(name) {
      let handler = on[name];
      if (!handler) {
        if (owner) { return owner.handleEvent.apply(null, arguments); }
        throw new Error('Missing event handler for ' + name);
      }
      handler.apply(null, slice.call(arguments, 1));
    }

  }


  // Given raw JSON-ML data, return a virtual DOM tree with auto-named nodes.
  function nameNodes(raw) {
    let tree = {};
    processItem(tree, raw);
    return tree;

    function processItem(nodes, item) {

      // Figure out what type of item this is and normalize data a bit.
      let type, first, tag;
      if (typeof item === 'number') {
        item = String(item);
      }
      if (typeof item === 'string') {
        type = 'text';
      }
      else if (Array.isArray(item)) {
        if (!item.length) { return; }
        first = item[0];
        if (typeof first === 'function') {
          type = 'component';
        }
        else if (typeof first === 'string') {
          tag = processTag(item);
          type = 'element';
        }
        else {
          item.forEach(function (child) {
            processItem(nodes, child);
          });
          return;
        }
      }
      else if (item instanceof HTMLElement) {
        type = 'el';
      }
      else {
        console.error(item);
        throw new TypeError('Invalid item');
      }

      // Find a unique name for this local namespace.
      let i = 1;
      let subType = type === 'element' ? tag.name : type === 'component' ? item[0].name : type;
      let id = type === 'element' ? tag.ref : type === 'component' ? item.key : null;
      let newPath = id ? subType + '-' + id : subType;
      while (nodes[newPath]) { newPath = subType + '-' + (id || '') + (++i); }

      let node;

      if (type === 'text') {
        nodes[newPath] = {
          text: item
        };
        return;
      }

      if (type === 'el') {
        nodes[newPath] = {
          el: item
        };
        return;
      }

      if (type === 'element') {
        let sub = {};
        node = nodes[newPath] = {
          tagName: tag.name,
        };
        if (!isEmpty(tag.props)) { node.props = tag.props; }
        if (tag.ref) { node.ref = tag.ref; }
        tag.body.forEach(function (child) {
          processItem(sub, child);
        });
        if (!isEmpty(sub)) { node.children = sub; }
        return;
      }

      if (type === 'component') {
        nodes[newPath] = {
          component: item[0],
          data: item.slice(1)
        };
        return;
      }

      throw new TypeError('Invalid type');
    }

  }

  // Parse and process a JSON-ML element.
  function processTag(array) {
    let props = {}, body;
    if (array[1] && array[1].constructor === Object) {
      let keys = Object.keys(array[1]);
      for (let i = 0, l = keys.length; i < l; i++) {
        let key = keys[i];
        props[key] = array[1][key];
      }
      body = array.slice(2);
    }
    else {
      body = array.slice(1);
    }
    let string = array[0];
    let name = string.match(TAG_MATCH);
    let tag = {
      name: name ? name[0] : 'div',
      props: props,
      body: body
    };
    let classes = string.match(CLASS_MATCH);
    if (classes) {
      classes = classes.map(stripFirst).join(' ');
      if (props.class) { props.class += ' ' + classes; }
      else { props.class = classes; }
    }
    let id = string.match(ID_MATCH);
    if (id) {
      props.id = stripFirst(id[0]);
    }
    let ref = string.match(REF_MATCH);
    if (ref) {
      tag.ref = stripFirst(ref[0]);
    }
    return tag;
  }

  function updateAttrs(node, attrs, old) {

    // Remove any attributes that were in the old version, but not in the new.
    Object.keys(old).forEach(function (key) {
      // Don't remove attributes still live.
      if (attrs && attrs[key]) { return; }

      // Special case to remove event handlers
      if (key.substr(0, 2) === 'on') {
        let eventName = key.substring(2);
        node.removeEventListener(eventName, old[key]);
      }

      // All other attributes remove normally including 'style'
      else {
        node.removeAttribute(key);
      }
      // console.log('unset ' + key)

      // Remove from virtual DOM too.
      old[key] = null;
    });

    // Add in new attributes and update existing ones.
    if (attrs) { forEach(attrs, function (key, value) {
      let oldValue = old[key];

      // Special case for object form styles
      if (key === 'style' && typeof value === 'object') {
        // Remove old version if it was in string form before.
        if (typeof oldValue === 'string') {
          node.removeAttribute('style');
          // console.log('unset style')
        }
        // Make sure the virtual DOM is in object form.
        if (!oldValue || typeof oldValue !== 'object') {
          oldValue = old.style = {};
        }
        updateStyle(node.style, value, oldValue);
        return;
      }

      // Skip any unchanged values.
      if (oldValue === value) { return; }

      // Record new value in virtual tree
      old[key] = value;

      // Add event listeners for attributes starting with 'on'
      if (key.substr(0, 2) === 'on') {
        let eventName = key.substring(2);
        // If an event listener is updated, remove the old one.
        if (oldValue) {
          node.removeEventListener(eventName, oldValue);
        }
        // Add the new listener
        node.addEventListener(eventName, value);
      }
      else if (key === 'checked' && node.nodeName === 'INPUT') {
        if (node.checked === value) { return; }
        node.checked = value;
      }
      // different way of updating the (actual) value for inputs
      else if (key === 'value' && node.nodeName === 'INPUT') {
        // Make sure the value is actually different.
        if (node.value === value) { return; }
        node.value = value;
      }
      // Handle boolean values as valueless attributes
      else if (typeof value === 'boolean') {
        if (value) { node.setAttribute(key, key); }
        else { node.removeAttribute(key); }
      }
      // handle normal attribute
      else {
        node.setAttribute(key, value);
      }

      // console.log('set ' + key)

    });}

  }

  function updateStyle(style, attrs, old) {
    // Remove any old styles that aren't there anymore
    forEach(old, function (key) {
      if (attrs && attrs[key]) { return; }
      old[key] = style[key] = '';
      // console.log('unstyled ' + key)
    });
    if (attrs) { forEach(attrs, function (key, value) {
      let oldValue = old[key];
      if (oldValue === value) { return; }
      old[key] = style[key] = attrs[key];
      // console.log('styled ' + key)
    }); }
  }

  function stripFirst(part) {
    return part.substring(1);
  }

  function isEmpty(obj) {
    return !Object.keys(obj).length;
  }

  let CLASS_MATCH = /\.[^.#$]+/g,
      ID_MATCH = /#[^.#$]+/,
      REF_MATCH = /\$[^.#$]+/,
      TAG_MATCH = /^[^.#$]+/;

  let slice = [].slice;
  function noop() {}

  return createComponent;

});
