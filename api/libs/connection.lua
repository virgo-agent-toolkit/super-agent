local postgresConnect = require('coro-postgres').connect

local psql
local options

local function setup(opts)
  options = opts
end

local function getConnection()
  if psql then return psql end
  assert(options, "Please setup options first")
  psql = postgresConnect(options)
  return psql
end

return {
  setup = setup,
  get = getConnection,
}
