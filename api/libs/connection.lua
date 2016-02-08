local postgresConnect = require('coro-postgres').connect

local psql
local options

local function setup(opts)
  options = opts
end

local function query(...)
  if not psql then
    assert(options, "Please setup options first")
    psql = postgresConnect(options)
  end
  return psql.query(...)
end

return {
  setup = setup,
  query = query,
}
