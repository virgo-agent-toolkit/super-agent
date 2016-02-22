module Account (
  Uuid, NewAccount, Row, Query, Columns, Rows, Stats, Results,
  create, read, update, delete, query) where

import Http exposing (Error)
import Task exposing (Task)
import Json.Decode as Decode exposing (Decoder, (:=))
import Json.Encode as Encode exposing (Value)

-- MODELS --

type alias Uuid = String
type alias NewAccount = {name: String}
type alias Account = {id: Uuid, name: String}
type alias Query = {
    name: String,
    offset: Int,
    limit: Int
  }
type alias Columns = (String, String)
type alias Row = (String, String)
type alias Rows = List Row
type alias Stats = (Int, Int, Int)
type alias Results = (Columns, Rows, Stats)


-- CODECS --


decodeResults: Decoder Results
decodeResults = Decode.tuple3 (,,)
  (Decode.tuple2 (,) Decode.string Decode.string)
  (Decode.list (Decode.tuple2 (,) Decode.string Decode.string))
  (Decode.tuple3 (,,) Decode.int Decode.int Decode.int)

decodeMaybeRow: Decoder (Maybe Account)
decodeMaybeRow = Decode.maybe (Decode.object2 Account
    ("id" := Decode.string)
    ("name" := Decode.string))

type alias Encoder a = (a -> Encode.Value)

encodeNewAccount: Encoder NewAccount
encodeNewAccount row =
  Encode.object [
    ("name", Encode.string row.name)
  ]

encodeRow: Encoder Account
encodeRow row =
  Encode.object [
    ("id", Encode.string row.id),
    ("name", Encode.string row.name)
  ]

encodeQuery: Encoder Query
encodeQuery query =
  Encode.object [
    ("name", Encode.string query.name),
    ("offset", Encode.int query.offset),
    ("limit", Encode.int query.limit)
  ]
encodeUuid: Encoder Uuid
encodeUuid = Encode.string

-- HELPER --
-- this is general and could be placed in a central location

makeCall: String -> (a -> Value) -> Decoder b -> a -> Task Error b
makeCall name encoder decoder arg =
    Encode.list [ encoder arg ]
    |> Encode.encode 0
    |> Http.string
    |> Http.post decoder ("http://localhost:8080/api/" ++ name)

-- API CALLS --

create: NewAccount -> Task Error Uuid
create = makeCall "account.create" encodeNewAccount Decode.string

read: Uuid -> Task Error (Maybe Account)
read = makeCall "account.read" encodeUuid decodeMaybeRow

update: Account -> Task Error Bool
update = makeCall "account.update" encodeRow Decode.bool

delete: Uuid -> Task Error Bool
delete = makeCall "account.delete" encodeUuid Decode.bool

query: Query -> Task Error Results
query = makeCall "account.query" encodeQuery decodeResults
