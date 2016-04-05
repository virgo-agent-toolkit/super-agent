# Super Agent

The Super Agent project is an ambitious project that makes it simple and secure
to monitor, diagnose, and repair various remote machines.  This also makes for
a great platform for building your own web based IDE to execute and develop
code on remote machines.

Wherever possible, the agent is portable to all major platforms, including
Windows.  Currently the agent is implemented using the [Luvit][] platform.
[LuaJit][] gives us a very fast, efficient, and easy to use scripting language.
[libuv][] gives us cross-platform system primitives such as TCP, UDP, timers,
sockets, file systems, etc.


There are currently 3 main components in this project:

- The **agent** which runs inside the remote machine and performs actions on
  behalf of users.  Also the agent can act as a proxy to reach other agents
  that are on machines that are behind firewalls and can only connect outward.

- A sample web-based **client** is provided.  This is not coupled tightly to the
  agent protocol, but rather shows an IDE-like interface that could be made to
  to consume the agent protocol.

- There is also an **api server** in progress that will perform tasks such as
  CRUD management of user accounts, agents and agent auth tokens, pools of
  agent proxies and their current state.

  In the current state, the api server is not functional, but will be used when
  the agent is deployed into large networks that require programatic
  configuration and management.


## Deputy Fife

The deputy is a self-contained executable built as a [luvi][] app and using many
libraries from the [luvit][] ecosystem.

The easiest way to build the agent is to [install][] [lit][] on your system and run:

```sh
lit make lit://virgo-agent-toolkit/fife
```

Running this command will download the source-code to the agent into your local
lit cache and compile it into a single zip file full of lua bytecode and static
assets.  It will then download and cache a `luvi` binary for your platform that
matches the requirements in the agent's manifest file.  The will be combined
into a single file in your current working directory known as `fife`. (Unless
you're on windows, in which case it will be `fife.exe`).  Move this to somewhere
in your path to install it.  Probably the same place you installed `lit`.

The next 3 subsections describe the various modes in which the agent can run.  For all
of them, you need to write a `fife.conf` file and run the `fife` agent using the file.

You can place the file at `/etc/fife.conf` or in the current working directory when
running the command, or by passing the path to the conf file.

```sh
fife path/to/fife.conf
```

This will run the agent in the foreground with the given configuration.

### Standalone Mode

The simplest way to get started is to run the agent in standalone mode.  In this
mode the agent listens on a websocket port for incoming connections directly and
handles them.  It also has a convenience option to serve a directory via http
in case you want to host your web client using the same process.  


#### Local-Only Test Server

For getting started quickly, clone this repo and run the agent from the
`super-agent/agent/` folder.

```sh
cd super-agent/agent
fife fife.config.local
```

This config file will listen locally without any kind of encryption or
authentication. Do **not** run this on a machine that is shared with untrusted
users!  This is generally meant for quick local testing on a developer's laptop.

The config file contains something like:

```lua
-- fife.conf
mode = "standalone"
ip = "127.0.0.1"
port = 7000
webroot = "/path/to/client"
```

Note that it also serves up the sample web client using the `webroot` config
option.  Simply point your browser (Chrome and Firefox are known to work) to
<http://localhost:7000/> and the client should boot up, connect to the agent
and present you with a colorful desktop and two buttons to get started.

You could use this on remote machines if you used ssh port forwarding and you
were the only user on the remote box, but other options may be better for that.

#### Remote Standalone with Authentication and Encryption

You can also deploy the agent to a remote machine you own for performing tasks
remotely through your browser.  Standalone makes this easy.  Just make sure to
change 3 things.

 - Listen on `0.0.0.0` or some know public IP address on your box.
 - Enable encryption by providing SSL certificates and a private key. *Don't
   reuse my sample keys on anything public*
 - Add basic authentication by providing a list of value username/password combos.

A config for this might look like:

```lua
-- fife.conf
mode = "standalone"
ip = "0.0.0.0"
port = 8443
webroot = "/path/to/client"
users = { -- Allow two users to login, "username" and "user2"
  "sha1:f88af9b0dd65189104b3cc416616572af8cb27b7", -- username:password hashed
  "plain:user2:password2",
}
tls = {
  key = "/path/to/key.pem",
  cert = "/path/to/cert.pem",
}
```

You can create a self-signed cert and key with the following command:

```sh
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -nodes -days 365
```

You will need to import the `cert.pem` file into your local cert trust store on
your machine or the browser will complain the server is not safe.

Also if you use port `443` and have a domain pointing to your box, you can get a
free certificate from [letsencrypt][] that will be trusted by all major
browsers.

### Proxy Mode

Sometimes you want to install the agent on something that is behind a firewall,
(such as a [Raspberry PI][] sitting in your router closet.)

Also you may simply wish to connect to several agents, but have a single place
to access them all with the same deployment of TLS/SSL keys and user
authentication credentials.

With proxy mode, you deploy two agents.  One will be on the machine to control,
that will be in *remote* mode.  The other will be on some public box listening
in *proxy* mode.  The remote agents will connect outwards to the proxy node.
Clients will also connect to the proxy node.

The options are similar to standalone mode since most deal with the listening
address, authentication and encryption.

```lua
-- fife.conf
mode = "proxy"
ip = "0.0.0.0"
port = 8443
webroot = "path/to/client"
users = { ... } -- Enter your users here
tls = { -- Enter your TLS key and cert here.
  key = ...
  cert = ...
}
```

Eventually, we will want to authenticate agents and a list of value tokens could
be listed in this config file, but that's not implemented yet.

### Remote Mode

Now that you have your proxy loaded, you can deploy one or more agents that
connect to it to make themselves available to clients of the proxy.

A remote agent has a very simple config:

```lua
mode = "remote"
-- ID of agent that the client will use to request this one.
id = "sample-agent"
-- authentication token, ignored for now
token = "agent-auth-token"
-- public url to the proxy agent server.
proxy = "wss://someurl:8443"
-- Optional cert used to verify the proxy hasn't been MITMed
ca = "/path/to/cert/used/in/proxy/cert.pem"
```

## Websocket Client

For quick testing of the agent, you can use a tool called [wscat][] to connect
to the agent and issue requests manually.

Building `wscat` is the same as building the `fife` command.

```sh
lit make lit://creationix/wscat
```

And then move the generated `wscat` file to somewhere in your path.

To connect to a standalone agent, you only need to connect to its root url
using the `schema-rpc` subprotocol.

```sh
wscat wss://myserver:8443/ schema-rpc
```

### Basic Requests

Once connected, you can test the connection using the `echo` command.

Form a request by passing a JSON array with request ID, then API name, then zero
or more arguments.  The request ID is namespaced to this client's connection and
the client can decide to reuse IDs whenever it wants to.

```json
[1,"echo","Hello"]
```

It should reply with the negative of the request id and zero or more result
values.  The echo command takes exactly one value of any kind and echos it back.

```json
[-1,"Hello"]
```

In the `schema-rpc` protocol messages are send as either [JSON][] in text frames
or [Msgpack][] in binary frames.  I'm using JSON here since `wscat` sends text
frames. The response will match whichever format you used to last send.

The current set of API functions is listed in the [platform.api][] file.  There
is a type checker in the agent that will give you useful error messages if you
omit an argument or use the wrong type.

### Serialized Functions

The protocol supports serializing callback functions and is used heavily for
streaming interfaces.  For example, if you want to scan for entries in a directory, you would use
the `scandir` call.  Its signature is:

```api
scandir (
  path: String
  entry: Emitter(
    name: String
    type: String
  )
) -> (exists: Boolean)
```

This means it accepts two arguments, a `String` and an `Emitter` function.  It
will call the emitter function for each entry in the directory and then emit the
result of the original call with a single value signifying if the directory
existed or not. (This is needed to tell the difference between an empty
directory and one that doesn't exist.)

To serialize a function in `wscat`, we use the special encoding `{"":id}`.

```json
[1,"scandir","/root",{"":2}]
```

The agent will respond with something like:

```json
[-2,".ash_history","file"]
[-2,".bash_history","file"]
[-2,".bashrc","file"]
[-2,".config","directory"]
[-2,".litconfig","file"]
[-2,".litdb.git","directory"]
[-2,".vim","directory"]
[-2,".viminfo","file"]
[-2,".vimrc","file"]
[-2,".wscat_history","file"]
[-2,"bin","directory"]
[-2,"fife.conf","file"]
[-2,"super-agent","directory"]
[-1,true]
```

Notice that the calls to your serialized function were prefixed with its ID
inverted.

The agent can also send your serialized functions. Try it with echo.

```json
[1,"echo",{"":2}]
```

The agent will respond with its deserialized version of your function,
serialized back into JSON.

```json
[-1,{"":4}]
```

You can then call this function using the negative of its ID, passing in as
many arguments as you want.

```json
[-4,"this","is",true]
```

The agent will respond with the same by calling your original function.

```json
[-2,"this","is",true]
```

## Sample Client

It's good to know the underlying protocol, especially if you're writing your own
agent, but to get started quickly I created a demo client that has a file
browser, text editor, image viewer, and terminal emulator (using the `pty`
function of the agent.)

The client is a purely browser-based application.  You can load [index.html][]
directly from a clone of this repo or point `webroot` in your standalone or
proxy agent to the client folder.

Then in a browser (Firefox and Chrome are known to work), load the static file and append the url to the agent in a hash.  For example: `https://myserver.org/#wss://myagent:8443/`


## Custom Scripts and Future Features

One of the main goals of this system is to provide a platform for programmers
of all skill levels to write and share scripts in a portable and controlled
environment for performing various tasks.  This can mean process automation
or quick diagnostic scripts, or maintenance tasks.

Currently there is the very beginning.  A `script(code:String)` command that
runs a lua script in a sandbox where all the platform functions are globally available.

This means that you can do complex tasks such as conditionally search for a file
containing certain contents and return the path once found, all remotely in the
agent, without needing to transfer all the intermediate results across the slow
network connection.

The sample client uses this to quickly query things like operating system,
username, home directory, etc in a single call so that when the user wants to
spawn a shell, it knows what the appropriate flags to send to the `pty` function
are.

In the future, there will be a capabilities based permissions system where
authenticated users will be authorized to work in specified scopes (much like
oauth scopes).  For example, you might give read-only access to someone who's
job is to look in the machine for potential problems, but not actually change
anything on the system.  The owner would probably want full access.  You could
restrict filesystem commands to certain system calls or restrict to certain
folders/files.

There will be a script publishing system where scripts can be written once and
published.  The system will analyze all the system calls made by the script and
assign it a default permissions scope.  Administrators can override this to
require less permissions for specific scripts, trusting in the script itself to
restrict the user properly (basically like how setuid binaries work in unix).

These scripts can be published and versioned to shared script repositories where
metadata like rating, usage tags, description, author, etc can be attached.

Some agents can be deployed with restrictive white-lists of pre-approved scripts
and users can only run those scripts within the parameters set forth in their
definitions.

Basically this system is aimed at being useful for a wide range of trust use-cases
from very limited to full access with fine grained control over what is allowed.

Also all actions will be optionally logged for later audits or simply to
remember what was done.


[Luvit]: https://luvit.io/
[luvi]: https://github.com/luvit/luvi
[lit]: https://github.com/luvit/lit/blob/master/README.md
[install]: https://luvit.io/install.html
[LuaJit]: http://luajit.org/
[libuv]: http://libuv.org/
[letsencrypt]: https://letsencrypt.org/
[Raspberry PI]: https://www.raspberrypi.org/
[JSON]: http://json.org/
[Msgpack]: http://msgpack.org/
[platform.api]: https://github.com/virgo-agent-toolkit/super-agent/blob/master/agent/platform.api
[index.html]: https://github.com/virgo-agent-toolkit/super-agent/blob/master/client/index.html
[wscat]: https://github.com/creationix/wscat
