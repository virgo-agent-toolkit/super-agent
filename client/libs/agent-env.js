define('libs/agent-env', function () {
  'use strict';
  var env;
  return function* (call) {
    return env || (env = yield* call('script',
      'local os = getos() '+
      'local user = os ~= "Windows" and user(getuid()) '+
      'return {os=os,'+
        'home=homedir(),'+
        'user=user,'+
        'hostname=hostname()'+
      '}'
    ));
  };
});
