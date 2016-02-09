local call = require('registry').call

-- Incoming requests are in the form:
-- [id, name, args...]
-- Outgoing responses are in the form:
-- [-id, result]
-- Outgoing errors are:
-- [0, err, id?]
-- Outgoing stream chunks are in the form:
-- [sid, chunk]
-- Incoming stream chunks are in the form:
-- [-sid, chunk]
-- End of stream messages are
-- [sid] or [-sid]
return function (req, read, write)
  p(req.headers)
  for frame in read do
    p(frame)
  end
  write()
end
