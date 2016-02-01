local getn = table.getn
local function connection(args)
  -- if args is a string then we need to parse that
  -- otherwise assume that args is a list in the proper order
  -- Or I can assume that args is a parameterized list with the proper values


  -- args[port] = args[port] OR 5432
  -- args[hostname] = args[hostname] || 127.0.0.1

  -- we are also not creating a connection here
  --which means that we can ignore port and hostname in here
  -- connection - net.creatConnection(args.port, args.hostname)
  -- we aren't doing events here
  -- query_queue = {}
  -- readyStart, closeState, started = false, false, false
  -- conn = this

  local readyStart, closeState, started = false, false, false


  local function sendMessage(type, args)
    --create frame
    --var buffer = (formatter[type].apply(this, args)).frame();
    if (debug > 0) then
      -- sys.debug("Sending " + type + ": " + JSON.stringify(args));
      if (debug > 2) then
        --sys.debug("->" + buffer.inspect().replace('<', '['));
      end
    end
  end
  -- connection.setTimeout(0)

  local queue = {}
  local function checkInput ()
    if(getn(queue) == 0) then
      return nil
    end
    local first = queue[0]
    local code = fromCharCode(first[0])
    local length = readInt32(first[])

    if (getn(first) < length + 5) then
      if (getn(queue) > 1) then
        -- Merge the first two buffers
        queue.shift() -- removes first element of array
        local b = new Buffer(first.length + queue[0].length)
        -- create a buffer of the length of first plus the first element in the queue
        first.copy(b)
        -- copy the first values over
        queue[0].copy(b, first.length)
        -- copy the values
        queue[0] = b
        return checkInput()
      end
      return
    end
  end

  --local message = first.slice(5,5 + length)
  --if (first.length == 5 + length) then
  --  queue.shift()
  --end

  --if (first.length ~= 5 + length) then
  --  queue[0] = first.slice(length + 5, first.length)
  --end

  -- if (exports.DEBUG > 1) then
  --  sys.debug("stream: "..code.." "..message.inspect())
  --end
  --command = responses[code](message)
  --command comes back as {offset, type, data}
  -- if (command[2]) then -- second argument is the type
  --  if (exports.DEBUG > 0) then
  --    sys.debug("Received " + command.type + ": " + JSON.stringify(command.args));
  --  end
  -- command.args.unshift(command.type)
  -- events.emit.apply(events, command.args) -- probably not necessary since we arent doing events
  -- end

  --checkInput()

end
