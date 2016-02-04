local connect = require('../coro-postgres').connect
local getenv = require('os').getenv
local p = require('pretty-print').prettyPrint

coroutine.wrap(function ()
  local psql = assert(connect {
    database = getenv("DATABASE") or getenv("USER"),
    password = getenv("PASSWORD")
  })
  p(psql)
  p(psql.query("SELECT 'Hello' AS greeting"))
  psql.close()
end)()
