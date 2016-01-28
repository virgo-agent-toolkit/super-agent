
    name(arg1, arg1, ...) -> result

- authentication will use headers

## REST Variant

- HTTP message is POST
- url path is name
- request is always array of positional arguments.
- response is single value
- request and response can be encoded as JSON or msgpack.
- defaults to JSON, but headers can specify otherwise.
- Use `application/msgpack` in standard HTTP headers to 
  opt in to format in connection.

## Websocket Variant

- connect with same auth and encoding headers as REST
- use subprotocol "virgo-rpc"
- request looks like `[id, name, arg1, arg2...]`
- response looks like `[-id, result]`

The AEP will handle re-mapping between clients and agents 
and remapping IDs.

Streams only work over msgpack and websocket.

When agents reply with streams, they will be encoded as 
opaque stream IDs. `{__stream__: sid}`

- agent sends `[sid, chunk]` (chunk is binary)
- client sends `[-sid, chunk]`
- to end a stream send nothing for chunk `[sid]`.

The AEP will be responsible for cleaning up orphaned
streams and sending proper shutdown messages if
disconnects happen.

- The aep will include a string reason if `[sid, reason]` 
(reason is string)

