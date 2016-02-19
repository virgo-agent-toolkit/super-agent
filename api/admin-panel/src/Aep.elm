module Aep where

import Http exposing (Error)
import Task exposing (Task)
import Json.Decode as Decode exposing (Decoder, (:=))
import Json.Encode as Encode exposing (Value)

-- MODELS --

type alias Uuid = String
type alias RowWithoutId = {hostname: String}
type alias Row = {id: Uuid, hostname: String}
type alias Query = {
    hostname: String,
    offset: Int,
    limit: Int
  }
type alias Columns = (String, String)
type alias Rows = List(String, String)
type alias Stats = (Int, Int, Int)
type alias Results = (Columns, Rows, Stats)


-- CODECS --

decodeResults: Decoder Results
decodeResults = Decode.tuple3 (,,)
  (Decode.tuple2 (,) Decode.string Decode.string)
  (Decode.list (Decode.tuple2 (,) Decode.string Decode.string))
  (Decode.tuple3 (,,) Decode.int Decode.int Decode.int)

decodeMaybeRow: Decoder (Maybe Row)
decodeMaybeRow = Decode.maybe (Decode.object2 Row
    ("id" := Decode.string)
    ("hostname" := Decode.string))

encodeRowWithoutId: RowWithoutId -> Encode.Value
encodeRowWithoutId row =
  Encode.list [
    Encode.object [
      ("hostname", Encode.string row.hostname)
    ]
  ]

encodeRow: Row -> Encode.Value
encodeRow row =
  Encode.list [
    Encode.object [
      ("id", Encode.string row.id),
      ("hostname", Encode.string row.hostname)
    ]
  ]

encodeQuery: Query -> Encode.Value
encodeQuery query =
  Encode.list [
    Encode.object [
      ("hostname", Encode.string query.hostname),
      ("offset", Encode.int query.offset),
      ("limit", Encode.int query.limit)
    ]
  ]

-- HELPER --

makeCall: String -> (a -> Value) -> Decoder b -> a -> Task Error b
makeCall name encoder decoder args =
    encoder args
    |> Encode.encode 0
    |> Http.string
    |> Http.post decoder ("http://localhost:8080/api/" ++ name)

-- API CALLS --

create: RowWithoutId -> Task Error Results
create = makeCall "aep.create" encodeRowWithoutId decodeResults

read: Uuid -> Task Error (Maybe Row)
read = makeCall "aep.read" Encode.string decodeMaybeRow

update: Row -> Task Error Bool
update = makeCall "aep.update" encodeRow Decode.bool

delete: Uuid -> Task Error Bool
delete = makeCall "aep.delete" Encode.string Decode.bool

query: Query -> Task Error Results
query = makeCall "aep.query" encodeQuery decodeResults
