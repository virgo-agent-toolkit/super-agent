-- To install the `coro-net` dependency run:
--    lit install creationix/coro-net
local connect = require('coro-net').connect
local coroWrapper = require('coro-wrapper')
local formatterMap = require('postgres-codec').formatter
local decodeRaw = require('postgres-codec').decode
local digest = require('openssl').digest.digest

-- we need our encoder/decoder to have a certain shape for coro-wrapper to work
-- we only have a formatter without an encoder right now
--

-- encoder: return a function that takes an item and encode it

-- decoder: return a function that takes a chunk and returns
-- the decoded chunk plus the leftovers

local function encode(message)
  -- message is a table with two values
  local request, data = message[1], message[2]
  local formatter = formatterMap[request]

  if not formatter then
    error('No such request: ' .. request)
  end

  return formatter(data)
end

local function decode (chunk)
  local offset, response, extra = decodeRaw(chunk)
  -- use offset to chop up chunk
  if not offset then
    return
  end

  return {response, extra}, string.sub(chunk, offset)
end


coroutine.wrap(function ()
  -- Assume a local server with $USER as username and database.

  local user = require('os').getenv("USER")
  local password = os.getenv('PASSWORD')
  local read, write = assert(connect({
    host = "127.0.0.1",
    port = 5432
  }))
  -- read/write are raw tcp versions of them
  read = coroWrapper.reader(read, decode)
  write = coroWrapper.writer(write, encode)

  print("Connected to server, sending startup message")
  write({'StartupMessage', {user=user,database=user}})

  print("Reading response through decoder")
  local message = read()
  p(message)





  -----------
  -- section 1
  -----------
  -- password will be a parameter passed in
  -- will also need a setUser
  if message[1] == 'AuthenticationMD5Password' then
    if not password then
      error('no password set')
    end

    if not user then
      error('no user set')
    end
    local salt = message[2]
    -- lua way to access environment variables
    -- If the wrong password is provided this fails with a list concatination error
    write({'PasswordMessage',
      'md5'..digest('md5',
        digest('md5', password..user)..
      salt)})
    -- make sure get AuthenticationOk. On error
  end

  if message[1] == 'AuthenticationKerberosV5' then
    write()
    error("Kerberos Dialog authentication not supported")
  end

  if message[1] == 'AuthenticationCleartextPassword' then
    write({'PasswordMessage', password})
  end

  if message[1] == 'AuthenticationSCMCredential' then
    -- only possible for local unix domain connections
  end


  if message[1] == 'AuthenticationGSS' then
    -- frontend initiates GSSAPI negotiation
    write({'PasswordMessage', ''--[[First part of GSSAPI data stream]]})
    message = read()
  end

  if message[1] == 'AuthenticationSSPI' then
    -- frontend has to initiate a SSPI negotiation
    write({'PasswordMessage', ''--[[First part of SSPI data stream]]})

    message = read()
  end

  -- continuation of SSPI and GSS or a previous GSSContinue...
  -- so this portion will be in its own loop.
  if message[1] == 'AuthenticationGSSContinue' then
    repeat
      --[[
      message contains response from previous step

      if the message indications more data is needed to complete
      the authentication, then the frontend must sund that data
      as another PasswordMessage
      ]]
      write({'PasswordMessage', ''--[[more of this stream]]})
      message = read()
    until message[1] ~= 'AuthenticationGSSContinue'
  end




  message = read()

  if message[1] == 'ErrorResponse' then
    p(message[2])
    write()
    error('Authentication error: '..message[2].M) -- error throws so nothing happens after this.
  end

  if message[1] == 'AuthenticationOk' then
    p('Authenticated successfully')
  end

  p(message)

  ----------
  -- end of section 1 (authentication)
  ----------






  --[[for message in read do
    p(message)
  end]]
  -- Close the connection when done.
  write()

end)()
