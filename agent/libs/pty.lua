local uv = require('uv')
local wrapStream = require('coro-channel').wrapStream

local ffi = require('ffi')
-- Define the bits of the system API we need.
ffi.cdef[[
  struct winsize {
      unsigned short ws_row;
      unsigned short ws_col;
      unsigned short ws_xpixel;   /* unused */
      unsigned short ws_ypixel;   /* unused */
  };
  int openpty(int *amaster, int *aslave, char *name,
              void *termp, /* unused so change to void to avoid defining struct */
              const struct winsize *winp);
]]
-- Load the system library that contains the symbol.
local util = ffi.load("util")

local function openpty(rows, cols)
  -- Lua doesn't have out-args so we create short arrays of numbers.
  local amaster = ffi.new("int[1]")
  local aslave = ffi.new("int[1]")
  local winp = ffi.new("struct winsize")
  winp.ws_row = rows
  winp.ws_col = cols
  util.openpty(amaster, aslave, nil, nil, winp)
  -- And later extract the single value that was placed in the array.
  return amaster[0], aslave[0]
end

return function (cols, rows, program, onexit)

  -- Create the pair of file descriptors
  local master, slave = openpty(cols, rows)

  -- Spawn the child process that inherits the slave fd as it's stdio.
  local child = uv.spawn(program, {
    stdio = {slave, slave, slave},
    detached = true
  }, onexit)

  -- Wrap the master fd in a uv pipe and then in a coro-stream.
  local pipe = uv.new_pipe(false)
  pipe:open(master)
  local cread, cwrite = wrapStream(pipe)

  return cread, cwrite, child
end
