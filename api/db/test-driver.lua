-- To install the `coro-net` dependency run:
--    lit install creationix/coro-net
local getUUID = require('./uuid4').getUUID
local connect = require('coro-net').connect
local os = require('os')
local postgresWrap = require('postgres-codec').wrap

coroutine.wrap(function ()
  -- Use environment variables to configure test connection
  -- Should work out of the box for Postgres.app
  local options = {
    username = os.getenv('USER'),
    database = os.getenv('DATABASE') or os.getenv('USER'),
    password = os.getenv('PASSWORD')
  }

  local read, write = assert(connect({
    host = "127.0.0.1",
    port = 5432
  }))

  print("Connected to server, sending startup message")
  local psql = postgresWrap(read, write, options)
  p("psql", psql)

  print("Authenticated, sending query")

  local sql = string.format(
    "INSERT INTO account (id, name) VALUES ('%s', '%s')",
    getUUID(), 'new account'
  )
  p(psql.query(sql))

  p(psql.query("SELECT * FROM account"))


  print("Closing the connection")
  write()
end)()
