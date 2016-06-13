## Requirement
Here is the quick instruction for anyone who wants to check out the remote execution POC (proof of concept) in the super agent.

You don't need to have knowledge of the techonology behind super agent. But you need to have basic knowledge of SSH, shell command in Linux and know how to use a browser.

## Install Luvi and Lit

```
curl -LO https://raw.githubusercontent.com/luvit/lit/master/get-lit.sh
sh get-lit.sh
sudo mv luvi lit /usr/local/bin/
```

What the above script does are:
- Download latest luvi binary for your platform from: <https://github.com/luvit/luvi/releases> and copy to `/usr/local/bin/`
- Download latest lit zip from: <https://lit.luvit.io/packages/luvit/luvit/latest.zip>
- Build lit executable in the current directory with: `luvi lit.zip -- make lit.zip /usr/local/bin/lit`

## Install Luvit and Fife
Now that we have lit installed, we can use it to automatically download and build any published app.

Let's install fife, the super-agent.
```
sudo lit make lit://virgo-agent-toolkit/fife /usr/local/bin/fife
```

## Configure Fife
We'll configure fife for local-only access to keep things simple and secure.

Create `fife.conf` in the current directory with the following content

```
mode = "standalone"
ip = "127.0.0.1"
port = 7000
webroot = "./super-agent"
```
## Download the client

Clone the super-agent repo recursivly from the current directory for fife process to find it

```
git clone --recursive https://github.com/virgo-agent-toolkit/super-agent.git
```


## Start fife.

run `fife` in current directory

It should show something like the following:

```
user@host:~$ fife
virgo-agent-toolkit/fife v0.4.1
Fife daemon mode detected.
Loading config file '/etc/fife.conf'
Creating local rpc server 'ws://127.0.0.1:7000/'
listening on local socket for cli clients { path = '/tmp/fife.sock', isTcp = false }
HTTP server listening at http://127.0.0.1:7000/
```

## Hook up the browser
Due to security concern, the super agent is not exposed to the internet.  If your are setting up super agent in a remote server and want to use browesr on your laptop, you can start the SSH tunnel using the following command:

```ssh -L 7000:localhost:7000 <username>@<remote IP or host name>```

## Run the Demo Script
The quick way is to run the demo script that will scan the system and look for files using the most disk space.

To do that, point your browser to the following URL and see the agent returning the data

<http://localhost:7000/dumb-client/index.html?gist=9906c50ab7276a7bbae778db942d6142&agent=ws://localhost:7000>

## Modify the Demo Script
You can modify the demo script to your liking and get a feel of writing script for agent to execute. To do that, point your browser to the following URL:

<http://localhost:7000/dumb-client-ide/index.html?gist=9906c50ab7276a7bbae778db942d6142&agent=ws://localhost:7000>

After you modify the script, simply reload the page to have the script executed.

## Play with the Terminal
For demo purpose, there is a terminal client that allows you to run random commands. This is the best way to explore the power of the super agent.

<http://localhost:7000/client/?agent=ws://localhost:7000>

## What next?
Like it? What more? Super agent is developed in the open.  Please visit the project page and submit issues for anything on your mind: 

<https://github.com/virgo-agent-toolkit/super-agent>