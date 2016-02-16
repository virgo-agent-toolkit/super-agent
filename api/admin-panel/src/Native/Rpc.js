Elm.Native.Rpc = {};
Elm.Native.Rpc.make = function(localRuntime) {

	localRuntime.Native = localRuntime.Native || {};
	localRuntime.Native.Rpc = localRuntime.Native.Rpc || {};
	if (localRuntime.Native.Rpc.values)
	{
		return localRuntime.Native.Rpc.values;
	}

	var Task = Elm.Native.Task.make(localRuntime);
	var Utils = Elm.Native.Utils.make(localRuntime);


	function call(name, args)
	{
		return Task.asyncFunction(function(callback) {
      console.log(name, args);
			console.log("TODO: send websocket request and wait for response");
			return callback(Task.succeed(Utils.Tuple0));
		});
	}

	return localRuntime.Native.Rpc.values = {
		call: call,
	};
};
