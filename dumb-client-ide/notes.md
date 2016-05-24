Exports contains:

 - css (will be namespaces in browser by transform)
 - js (will be run in custom context)
 - anything else (usually functions)

## Return values in anonymous functions

It would be nice if these functions could return values instead of depending on
callbacks.  We need to tweak the protocol so that all functions can return
values.

```
-> [1, "8ed91caeafecb44715f269ba41cf3833fdee345b"] -- ask for a custom function
<- [-1, {"":id}]  -- agent gives us function with id
-> [1,id] -- We call function with request id
<- [-1, true] -- agent responds through return value
```

## Sessions

We need sessions to make resource management sane and to make routing sane.

Server assigns addresses.

C->S CONNECT
S->C [Cid,Aid]
C->S [Cid,Aid,...]
S->C [Aid,Cid,...]
S->C [Aid,Cid] DISCONNECT

[from,to,reqId,fn,....] - CALL
[from,to,-reqId,....] - Respond
[from,to] - disconnect
