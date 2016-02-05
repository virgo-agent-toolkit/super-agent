# API Registry

This document is automatically generated from type annotations in the source of each module.

## Custom Types

The following type aliases are defined in this document:

### `Aep` ← `{hostname: String, id: Uuid}`

This alias is for existing AEP entries that have an ID.

### `AepWithoutId` ← `{hostname: String}`

This alias is for creating new AEP entries that don't have an ID yet

### `Page` ← `(Int, Int)`

This alias is s tuple of `limit` and `offset` for tracking position when paginating

### `Query` ← `{pattern: String}`

Structure for valid query parameters

## Functions

This server implements the following public functions:

### `aep.create(aep: AepWithoutId): Uuid`

This function creates a new AEP entry in the database.  It will return
the randomly generated UUID so you can reference the AEP.

### `aep.delete(id: Uuid): Uuid`

TODO: document me

### `aep.query(query: Query, page: Page): (Array<Aep>, Page)`

TODO: document me

### `aep.read(id: Uuid): Aep`

TODO: document me

### `aep.update(aep: Aep): Uuid`

TODO: document me

