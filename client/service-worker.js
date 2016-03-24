/*globals self*/
self.onfetch = function (evt) {
  'use strict';
  console.log('fetch', evt);
  evt.respondWith(new Promise(function (resolve, reject) {
    setTimeout(function () {
      resolve(
        new Response('<p>Hello from your friendly neighbourhood service worker!</p>', {
          headers: { 'Content-Type': 'text/html' }
        })
      );
    }, 1000);
  }));
};

console.log('Register me');
