define('libs/agent-env', function () {
  'use strict';
  var env;
  return function* (call) {
    return env || (env = yield* call('script',
      'return {' +
        'os = getos(),' +
        'home = homedir(),' +
        'user = getusername(),' +
        'hostname = hostname()' +
      '}'
    ));
  };
});
