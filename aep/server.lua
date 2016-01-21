-- single and double quotes are the same in lua
require('weblit-websocket')

local app = require('weblit-app')
local generateUUID
local keys = {}
app.bind({host="127.0.0.1", port=8080})
--.bind({host="127.0.0.1", port=8080}) would have done the exact same thing


local function newToken(req, res)
	--generate and store some sort of UUID and tie it to the currently authenticated user
	local uuid=generateUUID()
	keys[uuid]=true --eventually true should be the session... and even more eventually will be a db

	--keys is a hashmap, we can have anything as a key. Except nil

	-- so we are wanting to hand this token to the client so that it knows its associated with me
	res.code=200
	res.body=uuid.."\n"
	res.headers["Content-Type"]="text/plain"
end


app.use(require('weblit-logger'))
app.use(require('weblit-auto-headers'))
app.use(require('weblit-etag-cache'))

app.route({
	method = "POST",
	path = "/newAgentToken",
}, newToken)

app.use(require('weblit-static')("/Users/adam9500/workspace/super-agent/www"))
app.websocket({
  path = "/:cols/:rows/:program:",
  protocol = "xterm"
}, require('/Users/adam9500/workspace/super-agent/TTY/pipes'))


--p(require('/Users/adam9500/workspace/super-agent/TTY/pipes'))
--this is using a



function generateUUID()
	return string.format("%x", math.random()*0x100000000000)
end

app.start()
