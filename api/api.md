# API Registry

This document is automatically generated from type annotations in the source of each module.

## aep.create(aep: {hostname: String}): Uuid

This function creates a new AEP entry in the database.  It will return
the randomly generated UUID so you can reference the AEP.
## aep.delete(id: Uuid): Uuid

TODO: document me
## aep.query(query: {limit: Int, offset: Int, pattern: String}): {limit: Int, offset: Int, results: Array<{hostname: String, id: Uuid}>}

TODO: document me
## aep.read(id: Uuid): {hostname: String, id: Uuid}

TODO: document me
## aep.update(aep: {hostname: String, id: Uuid}): Uuid

TODO: document me
