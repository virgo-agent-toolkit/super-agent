local uv = require('uv')
--here we are just pulling in the wrapStream function
local wrapStream = require('coro-channel').wrapStream
local split = require('coro-split')
local openpty = require('./openptyWrapper.lua')


local function onSocket(req, read, write)
  p("just entered onSocket", openpty)
  local cols = tonumber(req.params.cols)
  local rows = tonumber(req.params.rows)
  local program = "/" .. req.params.program

  local master, slave = openpty(cols, rows)

  local child = uv.spawn(program, {
    stdio = {slave, slave, slave},
    detached = true
  }, function (...)
    p("child exit", ...)
  end)

  local pipe = uv.new_pipe(false)
  p(pipe)
  -- equivalent to pipe.open(pipe, master)
  pipe:open(master)
  local cread, cwrite = wrapStream(pipe)

  split(function ()
    for data in read do
      if data.opcode == 2 then
        cwrite(data.payload)
      end
    end
    cwrite()
  end, function ()
    for data in cread do
      write(data)
    end
    write()
  end)

  child:close()
  pipe:close()
end

return onSocket
