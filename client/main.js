define("main", function (require) {
  'use strict';

});

window.onload = function () {
  'use strict';
  let require = window.require;
  require.async('libs/run', function (err, run) {
    run(function* () {
      let rpc = yield require.async('libs/rpc');
      console.log(rpc);
    }, function (err) {
      if (err) { throw err; }
    });
  });
};
