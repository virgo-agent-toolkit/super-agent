# API Registry

This document is automatically generated from type annotations in the source of each module.

## Custom Types

The following type aliases are defined in this document:

### Aep = {hostname: String, id: Uuid}

This alias is for existing AEP entries that have an ID.

### AepWithoutId = {hostname: String}

This alias is for creating new AEP entries that don't have an ID yet
## Functions

This server implements the following public functions:

### aep.create(aep: AepWithoutId): Uuid

This function creates a new AEP entry in the database.  It will return
the randomly generated UUID so you can reference the AEP.

### aep.delete(id: Uuid): Uuid

TODO: document me

### aep.query(query: {limit: Int, offset: Int, pattern: String}): {limit: Int, offset: Int, results: Array<{hostname: String, id: Uuid}>}

TODO: document me

### aep.read(id: Uuid): Aep

TODO: document me

### aep.update(aep: Aep): Uuid

TODO: document me
