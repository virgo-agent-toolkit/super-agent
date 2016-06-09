# Super Agent Getting Started Guide for Windows

## Requirement

Here is the quick instruction for anyone who wants to check out the remote execution POC (proof of concept) in the super agent.

You don't need to have knowledge of the technology behind super agent. But you need to have basic knowledge of Microsoft Remote Desktop, Powershell command in Windows and know how to use a browser.

## Connect to windows server and set up Chrome browser

Use Microsoft Remote Desktop to connect to the windows server.  If you are using Mac, you need to install the Remote Desktop here: https://itunes.apple.com/us/app/microsoft-remote-desktop/id715768417?mt=12

The demo only works with Chrome or Firefox. Install Chrome browser <https://www.google.com/chrome/browser/desktop/>

## Install Luvi and Lit

Download the Powershell script here and run it: <https://github.com/luvit/lit/blob/master/get-lit.ps1>

## Install Luvit and Fife

Now that we have lit installed, we can use it to automatically download and build any published app.

Let's install fife, the super-agent.
```
Set-ExecutionPolicy Unrestricted
.\lit.exe make lit://virgo-agent-toolkit/fife fife.exe
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

If you don't have git, download and install git from here <https://git-scm.com/download/win>

Clone the super-agent repo recursivly from the same directory where `fife.exe` file was created in the above command

```
git clone --recursive https://github.com/virgo-agent-toolkit/super-agent.git
```

## Start fife

Run `.\fife.exe` in current directory

It should show something like the following:

```
PS C:\Users\Administrator> .\fife.exe
virgo-agent-toolkit/fife v0.4.1
Fife daemon mode detected.
Loading config file 'C:\\Users\\Administrator\\fife.conf'
Creating local rpc server 'ws://127.0.0.1:7000/'
listening on local socket for cli clients { host = '127.0.0.1', isTcp = true, port = 23258 }
HTTP server listening at http://127.0.0.1:7000/
```

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