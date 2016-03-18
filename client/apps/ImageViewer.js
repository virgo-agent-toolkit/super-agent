define('apps/ImageViewer', function (require) {
  'use strict';

  var run = require('libs/run');
  var guessMime = require('libs/mime');

  ImageViewer.title = 'ImageViewer';
  return ImageViewer;
  function* ImageViewer(call, runCommand, file) {
    var content = yield* call('readbinary', file);
    var blob = new Blob( [ content ], { type: guessMime(file) } );
    var urlCreator = window.URL || window.webkitURL;
    var imageUrl = urlCreator.createObjectURL( blob );
    var img = document.createElement('img');
    img.setAttribute('src', imageUrl);
    
    yield function (cb) {
      var done = false;
      function once() {
        if (done) { return; }
        done = true;
        return cb();
      }
      img.onload = function() {
        app.initialWidth = img.width;
        app.initialHeight = img.height;
        once();
      }
      setTimeout(once, 100);
    };
    
    return app;
    function app(win) {
      win.title = file;
      var style = win.container.style;
      style.backgroundImage = 'url(' + imageUrl + ')';
      style.backgroundPosition = 'center center';
      style.backgroundRepeat =  'no-repeat';
      style.backgroundSize = 'contain';
      style.backdropFilter = 'blur(10px)';
    }  
  }
});
