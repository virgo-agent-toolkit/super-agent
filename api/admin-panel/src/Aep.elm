module Aep (
  Uuid, NewAep, Row, Query, Columns, Rows, Stats, Results,
  create, read, update, delete, query) where

import Http exposing (Error)
import Task exposing (Task)
import Json.Decode as Decode exposing (Decoder, (:=))
import Json.Encode as Encode exposing (Value)

-- MODELS --

type alias Uuid = String
type alias NewAep = {hostname: String}
type alias Aep = {id: Uuid, hostname: String}
type alias Query = {
    hostname: String,
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

decodeMaybeRow: Decoder (Maybe Aep)
decodeMaybeRow = Decode.maybe (Decode.object2 Aep
    ("id" := Decode.string)
    ("hostname" := Decode.string))

type alias Encoder a = (a -> Encode.Value)

encodeNewAep: Encoder NewAep
encodeNewAep row =
  Encode.object [
    ("hostname", Encode.string row.hostname)
  ]

encodeRow: Encoder Aep
encodeRow row =
  Encode.object [
    ("id", Encode.string row.id),
    ("hostname", Encode.string row.hostname)
  ]

encodeQuery: Encoder Query
encodeQuery query =
  Encode.object [
    ("hostname", Encode.string query.hostname),
    ("offset", Encode.int query.offset),
    ("limit", Encode.int query.limit)
  ]
encodeUuid: Encoder Uuid
encodeUuid = Encode.string

-- HELPER --

makeCall: String -> Encoder a -> Decoder b -> a -> Task Error b
makeCall name encoder decoder arg =
    Encode.list [ encoder arg ]
    |> Encode.encode 0
    |> Http.string
    |> Http.post decoder ("http://localhost:8080/api/" ++ name)

-- API CALLS --

create: NewAep -> Task Error Uuid
create = makeCall "aep.create" encodeNewAep Decode.string

read: Uuid -> Task Error (Maybe Aep)
read = makeCall "aep.read" encodeUuid decodeMaybeRow

update: Aep -> Task Error Bool
update = makeCall "aep.update" encodeRow Decode.bool

delete: Uuid -> Task Error Bool
delete = makeCall "aep.delete" encodeUuid Decode.bool

query: Query -> Task Error Results
query = makeCall "aep.query" encodeQuery decodeResults
