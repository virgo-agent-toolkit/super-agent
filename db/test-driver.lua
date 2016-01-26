-- To install the `coro-net` dependency run:
--    lit install creationix/coro-net
local connect = require('coro-net').connect
local formatter = require('postgres-codec').formatter
local decode = require('postgres-codec').decode

coroutine.wrap(function ()
  -- Assume a local server with $USER as username and database.
  local user = require('os').getenv("USER")

  local read, write = assert(connect({
    host = "127.0.0.1",
    port = 5432
  }))
  print("Connected to server, sending startup message")
  write(formatter.StartupMessage({user=user,database=user}))

  print("Reading response through decoder")
  for chunk in read do
    p(chunk)
    p(decode(chunk))
  end

end)()
