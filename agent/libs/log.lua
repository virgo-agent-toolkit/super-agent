local dump = require('pretty-print').dump
local colorize = require('pretty-print').colorize
local m = {
  level = 5 -- Default to most verbose logging for now while in prototype stage
}

local levels = {
  "Fatal: ", -- This message should always be shown and probably reported.
  "Error: ", -- This is a real problem and should not be ignored.
  "Warning: ", -- This is probably a problem, but maybe not.
  "", -- This is for informational purposes only.
  "", -- This message is super chatty, but useful for debugging
}
local colors = {
  'failure',
  'err',
  'highlight',
  'userdata',
  'property'
}

function m.log(level, message, ...)
  if level > m.level then return end
  local parts = {}
  local data = table.pack(...)
  for i = 1, data.n do
    parts[i] = ' ' .. dump(data[i])
  end
  print(colorize(colors[level], levels[level] .. message) .. table.concat(parts))
end
return m
