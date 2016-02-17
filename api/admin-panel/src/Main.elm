module Main where

import Html exposing (form,h1,text,label,input,div,button,table,thead,tbody,tr,th,td,i,a)
import Html.Events exposing (onClick,on,targetValue)
import Html.Attributes exposing (id,for,type',value,class,href)
import Http
import Task exposing (Task, andThen)
import Json.Decode as Decode
import Json.Encode as Encode
import StartApp as StartApp
import Effects exposing (Effects, Never)
import String exposing (toInt)
import Char

-- MODEL --
type alias Model =
  { hostname: String
  , offset: Int
  , limit: Int
  , results: Maybe (Result Http.Error Results)
  }

type alias Columns = (String, String)
type alias Rows = List Row
type alias Row = (String, String)
type alias Stats = (Int, Int, Int)
type alias Results = (Columns, Rows, Stats)


init : (Model, Effects Action)
init = (
  { hostname = "*"
  , offset = 0
  , limit = 20
  , results = Nothing
  }, doQuery "*" 0 20)

-- UPDATE --

type Action
  = Query
  | Hostname String
  | Offset String
  | Limit String
  | QueryResults (Result Http.Error Results)
  | Edit String
  | Delete String
  | Changed (Result Http.Error Bool)


update: Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    Hostname value ->
      ({model | hostname = value}, Effects.none)
    Offset value ->
      case toInt value of
        Ok num -> ({model | offset = num}, Effects.none)
        Err _ -> (model, Effects.none)
    Limit value ->
      case toInt value of
        Ok num -> ({model | limit = num}, Effects.none)
        Err _ -> (model, Effects.none)
    Query ->
       (model, doQuery model.hostname model.offset model.limit)
    QueryResults results ->
       ({model | results = Just results }, Effects.none)
    Edit id ->
      (model, Effects.none)
    Delete id ->
      (model, deleteNode id)
    Changed (Ok True) ->
      (model, doQuery model.hostname model.offset model.limit)
    Changed (Ok False) ->
      (model, Effects.none)
    Changed (Err err) ->
      ({model | results = Just(Err err)}, Effects.none)


-- VIEW --

onInput: Signal.Address Action -> (String -> Action) -> Html.Attribute
onInput address action =
  on "input" targetValue (\str -> Signal.message address (action str))

renderTable: Signal.Address Action -> Results -> Html.Html
renderTable address (columns, rows, stats) =
  table [class "table table-striped table-hover table-bordered"] [
    renderHead columns,
    renderBody address rows
  ]

capitalize : String -> String
capitalize s =
  case String.uncons s of
    Just (c,ss) -> String.cons (Char.toUpper c) ss
    Nothing -> s

renderHead : Columns -> Html.Html
renderHead (n1, n2) =
  thead [] [
    th [] [ text (capitalize n1) ],
    th [] [ text (capitalize n2) ]
  ]

renderBody : Signal.Address Action -> Rows -> Html.Html
renderBody address rows =
  tbody [] (List.map (renderRow address) rows)

renderRow : Signal.Address Action -> Row -> Html.Html
renderRow address (id, hostname) =
  tr [] [
    td [] [ text id ],
    td [] [ text hostname ],
    td [] [
      i [ class "fa fa-pencil button alterar"
        , onClick address (Edit id)
        ] [],
      i [ class "fa fa-trash button excluir"
        , onClick address (Delete id)
        ] []
    ]
  ]

renderForm : Signal.Address Action -> Model -> Html.Html
renderForm address model =
  form [ class "form-horizontal" ] [
    div [class "form-group"] [
      label [
        class "col-sm-2 control-label",
        for "hostname"
      ] [ text "Hostname" ],
      div [ class "col-sm-10" ] [
        input [
          class "form-control",
          id "hostname",
          type' "text",
          value model.hostname ,
          onInput address Hostname
        ] []
      ]
    ],
    div [class "form-group"] [
      label [
        class "col-sm-2 control-label",
        for "offset"
      ] [ text "Offset" ],
      div [ class "col-sm-10" ] [
        input [
          class "form-control",
          id "offset",
          type' "number",
          value (toString model.offset),
          onInput address Offset
        ] []
      ]
    ],
    div [class "form-group"] [
      label [
        class "col-sm-2 control-label",
        for "limit"
      ] [ text "Limit: " ],
      div [ class "col-sm-10" ] [
        input [
          class "form-control",
          id "limit",
          type' "number",
          value (toString model.limit),
          onInput address Limit
        ] []
      ]
    ],
    div [class "form-group"] [
      div [class "col-sm-offset-2 col-sm-10"] [
        a [
          href "#",
          class "btn btn-primary active",
          onClick address Query
        ] [ text "Query" ]
      ]
    ]
  ]

view: Signal.Address Action -> Model -> Html.Html
view address model = div [ class "container" ]
  [
    h1 [] [ text "Agent Endpoints" ],
    renderForm address model,
    case model.results of
      Nothing -> text "Loading..."
      Just (Ok results) -> renderTable address results
      Just (Err err) -> text ("Error: " ++ (case err of
        Http.Timeout -> "Timeout"
        Http.NetworkError -> "Network Error"
        Http.UnexpectedPayload err -> "Unexpected Payload: " ++ err
        Http.BadResponse code message -> "Bad Response: " ++ (toString code) ++ " " ++ message
      ))
  ]
-- EFFECTS --

doQuery: String -> Int -> Int -> Effects Action
doQuery hostname offset limit =
  let
    decode = Decode.tuple3 (,,)
      (Decode.tuple2 (,) Decode.string Decode.string)
      (Decode.list (Decode.tuple2 (,) Decode.string Decode.string))
      (Decode.tuple3 (,,) Decode.int Decode.int Decode.int)
  in
    Encode.list [Encode.object[
      ("hostname",Encode.string hostname),
      ("offset",Encode.int offset),
      ("limit",Encode.int limit)
    ]]
      |> Encode.encode 0
      |> Http.string
      |> Http.post decode "http://localhost:8080/api/aep.query"
      |> Task.toResult
      |> Task.map QueryResults
      |> Effects.task

deleteNode: String -> Effects Action
deleteNode id =
  let
    decode = Decode.bool
  in
    Encode.list [Encode.string id]
      |> Encode.encode 0
      |> Http.string
      |> Http.post decode "http://localhost:8080/api/aep.delete"
      |> Task.toResult
      |> Task.map Changed
      |> Effects.task

-- MAIN --

app: StartApp.App Model
app =
  StartApp.start
    { init = init
    , update = update
    , view = view
    , inputs = []
    }


main: Signal Html.Html
main =
  app.html


port tasks : Signal (Task.Task Never ())
port tasks =
  app.tasks
