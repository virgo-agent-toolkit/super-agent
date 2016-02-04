
## AEP

- create({hostname})
- read(uuid)
- update(uuid, {hostname})
- delete(uuid)
- query({pattern}, {limit,offset})


## ACCOUNT

- create({name})
- read(uuid)
- update(uuid, {name})
- delete(uuid)
- query({pattern}, {limit,offset})

## TOKEN

- create({description})
- read(uuid)
- update(uuid, {description})
- delete(uuid)
- query({account_id,pattern}, {limit,offset})

## AGENT

- create({name})
- read(uuid)
- update(uuid, {name})
- delete(uuid)
- list({limit,offset})
- query({account_id,pattern}, {limit,offset})

## EVENTS

- log(timestamp, data)
- query(event_query, {limit,offset})

```js
// event_query format
{
  after: TIMESTAMP,
  before: TIMESTAMP,
  account_id: ID,
  agent_id: ID,
}
```
