-- To install the `coro-net` dependency run:
--    lit install creationix/coro-net
local connect = require('coro-net').connect
local coroWrapper = require('coro-wrapper')
local encode = require('postgres-codec').encode
local decode = require('postgres-codec').decode
local digest = require('openssl').digest.digest
local os = require('os')

-- Input is read/write pair for raw data stream and options table
-- Output is query function for sending queries
local function postgresWrap(read, write, options)
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
      local inner = digest('md5', options.password .. options.username)
      write { 'PasswordMessage',
        'md5'.. digest('md5', inner .. salt)
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
      p(message)
      error("Authentication error:" .. message[2].M)
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
        p(message)
        error("Server Error: " .. message[2].M)
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
          -- TODO: do type conversions so not everything is strings
          row[field] = value
        end
      elseif message[1] == "CommandComplete" then
        summary = message[2]
      elseif message[1] == "ReadyForQuery" and waiting then
        local thread = waiting
        waiting = nil
        assert(coroutine.resume(thread, rows, description, summary))
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

  return {
    params = params,
    query = query,
  }
end


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
  p(psql.query("SELECT * FROM account"))


  print("Closing the connection")
  write()
end)()
