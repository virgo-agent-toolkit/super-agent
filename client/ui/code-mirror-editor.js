define('ui/code-mirror-editor', function (require) {
  'use strict';

  let CodeMirror = require('codemirror/lib/codemirror');
  require('codemirror/addon/edit/closebrackets');
  require('codemirror/addon/comment/comment');
  require('codemirror/keymap/sublime');
  require('codemirror/addon/hint/anyword-hint');
  require('codemirror/addon/hint/show-hint');
  require('cm-jackl-mode');
  require('cm-jon-mode');

  return CodeMirrorEditor;

  function CodeMirrorEditor(emit) {
    let id;
    let code, mode, theme;
    let el;
    let cm = new CodeMirror(function (root) {
      el = root;
    }, {
      keyMap: 'sublime',
      // lineNumbers: true,
      rulers: [{ column: 80 }],
      autoCloseBrackets: true,
      matchBrackets: true,
      showCursorWhenSelecting: true,
      styleActiveLine: true,
    });
    setTimeout(function () {
      cm.refresh();
    }, 0);

    cm.on('focus', function () {
      emit('focus', id);
    });

    let replacements = {
      'lambda': 'λ',
      '*': '×',
      '/': '÷',
      '<=': '≤',
      '>=': '≥',
      '!=': '≠',
    };

    cm.on('change', function (cm, change) {
      if (mode !== 'jackl' || change.text[0] !== ' ') { return; }
      let type = cm.getTokenTypeAt(change.from);
      if (type !== 'operator' && type !== 'builtin') { return; }
      let token = cm.getTokenAt(change.from, true);
      let replacement = replacements[token.string];
      if (!replacement) { return; }
      let line = change.to.line;
      cm.replaceRange(replacement, {
        ch: token.start,
        line: line
      }, {
        ch: token.end,
        line: line
      });
    });

    return { render: render };

    function render(isDark, props) {
      id = props.id;
      let newTheme = isDark ? 'notebook-dark' : 'notebook';
      if (newTheme !== theme) {
        theme = newTheme;
        cm.setOption('theme', theme);
      }
      if (props.mode !== mode) {
        mode = props.mode;
        cm.setOption('mode', mode);
      }
      if (props.code !== code) {
        code = props.code;
        cm.setValue(code);
      }
      if (props.focused && !cm.hasFocus()) {
        cm.focus();
      }
      return el;
    }
  }
});
