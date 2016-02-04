# Luvit Schema Tool

This library allows you to decorate public API functions with strict runtime
typechecking.  You can declare the types using a clear declarative syntax
using actual type object references (to enable extensibility).

## Installing

The easiest way to install for use in a project is using `lit` from
 [luvit.io](https://luvit.io/).

```sh
lit install creationix/schema
```

## Example

For example, suppose you had a function that added two integers and returned a
new integer.  This could be defined using:

```lua
-- Load the wrapper function and the Int type
local schema = require 'schema'
local addSchema = schema.addSchema
local Int = schema.Int

-- Simple untyped function
local function add(a, b)
  return a + b
end

-- Add runtime type checking and error reporting.
add = assert(addSchema(
  "add",
  {
    {"a",Int},
    {"b",Int}
  },
  Int,
  add
))
```

You can then use `add` as before, except if the input or output values don't
match the declared types the wrapper function with return with `nil, errorMessage`
explaining in detail where the mismatch happened.

## Built-in Types

- `Any` - Will match any non-nil value.

- `Truthy` - Will match any value except nil and false. false)

- `Int` - Will match whole numbers.

- `Number` - Will match any numbers.

- `String` - Will match only strings

- `Bool` - Will match only booleans.

- `Function` - Will match functions or tables with a `__call` metamethod.

- `Array(T)` - Will match tables who's indexes are only `1..n`.  Also it will
  match the values to make sure they match type T.  You can pass in any value.

- `Record` - Match using structural typing, for example `{name=String,age=Int}`.
  This will match tables that contain at least the given string keys with
  matching types.  Extra fields will be ignored.

- `Tuple` - Match a table being used as a tuple.  For example `{String, Int}`
  will match only tables with length 2 who's have matching typed values.

- `Type` - Matches a type.  This means it could be a record or tuple literal or
  a special table with the `__typeName` metamethod.

## API Wrapper

There is a utility function `addSchema` that has the following schema signature which can be obtained by simply using `tostring(addSchema)`:

```ts
addSchema(
  name: String,
  inputs: Array<(String, Type)>,
  output: Type,
  fn: Function
): Function
```

The `addSchema` function typechecks itself using the following lua code.

```lua
addSchema = assert(addSchema(
  "addSchema",
  {
    {"name", String},
    {"inputs", Array({String,Type})},
    {"output", Type},
    {"fn", Function}
  },
  Function,
  addSchema
))
```
