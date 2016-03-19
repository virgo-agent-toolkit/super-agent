define('apps/ImageViewer', function (require) {
  'use strict';

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
        var width = img.width;
        var height = img.height;
        if (width > 720) {
          height = Math.floor(720*height/width);
          width = 720;
        }
        if (height > 400) {
          width = Math.floor(400*width/height);
          height = 400;
        }
        app.initialWidth = width;
        app.initialHeight = height;
        once();
      };
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
