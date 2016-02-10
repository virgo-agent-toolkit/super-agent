--[[lit-meta
  name = "creationix/coro-postgres"
  version = "0.4.4"
  dependencies = {
    "creationix/coro-wrapper@2.0.0",
    "creationix/coro-net@2.0.0",
    "creationix/postgres-codec@0.2.0",
    "creationix/md5@1.0.2"
  }
  homepage = "https://github.com/virgo-agent-toolkit/super-agent/blob/master/libs/postgres"
  description = "coro-net enabled postgres client using postgres-codec."
  tags = {"coro", "psql", "postgres", "", "db", "database"}
  license = "MIT"
  contributors = {
    "Tim Caswell",
    "Adam Martinek",
  }
]]

local p = require('pretty-print').prettyPrint
local netConnect = require('coro-net').connect
local coroWrapper = require('coro-wrapper')
local encode = require('postgres-codec').encode
local decode = require('postgres-codec').decode
local getenv = require('os').getenv
local md5 = require('md5').sumhexa

local function formatError(msg)
  return string.format(
    "%s: %s %s:%s (%s) - %s",
    msg.S or "?",
    msg.F or "?",
    msg.L or "?",
    msg.C or "?",
    msg.R or "?",
    msg.M or "?")
end
-- Input is read/write pair for raw data stream and options table
-- Output is query function for sending queries
local function wrap(options, read, write, socket)
  assert(options.username, "options.username is required")
  assert(options.database, "options.database is required")

  -- Apply the codec to the stream
  read = coroWrapper.reader(read, decode)
  write = coroWrapper.writer(write, encode)

  -- Send the StartupMessage
  write {'StartupMessage', {
    user = options.username,
    database = options.database
  }}

  -- Handle authentication state machine using a simple loop
  while true do
    local message = read()
    if message[1] == 'AuthenticationOk' then
      break
    elseif message[1] == 'AuthenticationMD5Password' then
      assert(options.password, "options.password is needed")

      local salt = message[2]
      local inner = md5(options.password .. options.username)
      write { 'PasswordMessage',
        'md5'.. md5(inner .. salt)
      }
    elseif message[1] == 'AuthenticationCleartextPassword' then
      write {'PasswordMessage', options.password}

    elseif message[1] == 'AuthenticationKerberosV5' then
      error("TODO: Implement AuthenticationKerberosV5 authentication")
    elseif message[1] == 'AuthenticationSCMCredential' then
      -- only possible for local unix domain connections
      error("TODO: Implement AuthenticationSCMCredential authentication")
    elseif message[1] == 'AuthenticationGSS' then
      -- frontend initiates GSSAPI negotiation
      error("TODO: Implement AuthenticationGSS authentication")
      -- write({'PasswordMessage', ''--[[First part of GSSAPI data stream]]})
    elseif message[1] == 'AuthenticationSSPI' then
      -- frontend has to initiate a SSPI negotiation
      error("TODO: Implement AuthenticationSSPI authentication")
      -- write({'PasswordMessage', ''--[[First part of SSPI data stream]]})
    elseif message[1] == 'AuthenticationGSSContinue' then
      -- continuation of SSPI and GSS or a previous GSSContinue...
      error("TODO: Implement AuthenticationGSSContinue authentication")
      -- repeat
      --   --[[
      --   message contains response from previous step
      --
      --   if the message indications more data is needed to complete
      --   the authentication, then the frontend must sund that data
      --   as another PasswordMessage
      --   ]]
      --   write({'PasswordMessage', ''--[[more of this stream]]})
      --   message = read()
      -- until message[1] ~= 'AuthenticationGSSContinue'
    elseif message[1] == 'ErrorResponse' then
      error(formatError(message[2]))
    else
      error("Unexpected response type: " .. message[1])
    end
  end

  local params = {}

  while true do
    local message = read()
    if message[1] == 'ReadyForQuery' then
      break
    elseif message[1] == 'ParameterStatus' then
      params[ message[2][1] ] = message[2][2]
    elseif message[1] == 'BackendKeyData' then
      params.backend_key_data = {
        pid = message[2],
        secret = message[3]
      }
    else
      p(message)
      error("Unexpected message: " .. message[1])
    end
  end


  local waiting

  coroutine.wrap(function ()
    local description
    local rows
    local summary
    for message in read do
      if message[1] == "ErrorResponse" then
        if waiting then
          local t
          t, waiting = waiting, nil
          return assert(coroutine.resume(t, nil, formatError(message[2]), message[2]))
        end
        error(formatError(message[2]))
      elseif message[1] == "RowDescription" then
        description = message[2]
        rows = {}
      elseif message[1] == "DataRow" then
        local row = {}
        rows[#rows + 1] = row
        for i = 1, #description do
          local column = description[i]
          local field = column.field
          local value = message[2][i]
          local typeId = column.typeId
          if typeId == 16 then -- boolean
            value = value == "t"
          elseif typeId == 20 -- BIGINT
              or typeId == 23 -- INTEGER
              or typeId == 700 -- Real
              or typeId == 701 -- Double
              then
            value = tonumber(value)
          end
          row[field] = value
        end
      elseif message[1] == "CommandComplete" then
        summary = message[2]
      elseif message[1] == "ReadyForQuery" and waiting then
        local t, r, d, s
        t, waiting = waiting, nil
        r, rows = rows, nil
        d, description = description, nil
        s, summary = summary, nil
        assert(coroutine.resume(t, {
          rows = r,
          description = d,
          summary = s
        }))
      else
        p(message)
        error("Unexpected message from server: " .. message[1])
      end
    end
  end)()

  local function query(sql)
    write {'Query', sql}
    waiting = coroutine.running()
    return coroutine.yield()
  end

  local function close()
    return write()
  end

  return {
    close = close,
    params = params,
    query = query,
    socket = socket
  }
end

local function connect(options)
  local connectionOptions
  if options.path then
    connectionOptions = { path = options.path }
  else
    connectionOptions = {
      host = options.host or "localhost",
      port = options.port or 5432
    }
  end
  local psqlOptions = {
    username = options.username or getenv("USER"),
    database = options.database or getenv("USER"),
    password = options.password
  }
  local read, write, socket = netConnect(connectionOptions)
  if not read then
    -- write is the error message in case of failure
    return nil, write
  end
  return wrap(psqlOptions, read, write, socket)
end

return {
  connect = connect,
  wrap = wrap,
}
