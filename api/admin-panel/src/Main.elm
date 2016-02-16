import Html exposing (form,h1,text,label,input,div,button,table,thead,tbody,tr,th,td)
import Html.Events exposing (onClick,on,targetValue)
import Html.Attributes exposing (id,for,type',value,class)
import Http
import Task exposing (Task, andThen)
import Json.Decode as Decode
import Json.Encode as Encode
import StartApp as StartApp
import Effects exposing (Effects, Never)
import String exposing (toInt)


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
init = ({hostname="*",offset=0,limit=20,results=Nothing}, Effects.none)

-- UPDATE --

type Action
  = Query
  | Hostname String
  | Offset String
  | Limit String
  | QueryResults (Result Http.Error Results)


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

-- VIEW --

onInput: Signal.Address Action -> (String -> Action) -> Html.Attribute
onInput address action =
  on "input" targetValue (\str -> Signal.message address (action str))

renderTable: Results -> Html.Html
renderTable (columns, rows, stats) =
  table [] [
    renderHead columns,
    renderBody rows
  ]

renderHead : Columns -> Html.Html
renderHead (n1, n2) =
  thead [] [
    th [] [ text n1 ],
    th [] [ text n2 ]
  ]

renderBody : Rows -> Html.Html
renderBody rows =
  tbody [] (List.map renderRow rows)

renderRow : Row -> Html.Html
renderRow (id, hostname) =
  tr [] [
    td [] [ text id ],
    td [] [ text hostname ]
  ]

view: Signal.Address Action -> Model -> Html.Html
view address model = div []
  [
    div [ id "signup-form" ] [
      h1 [] [ text "AEP Query" ],
      label [ for "hostname" ] [ text "Hostname: " ],
      input [
        id "hostname",
        type' "text",
        value model.hostname ,
        onInput address Hostname
      ] [],
      label [ for "offset" ] [ text "Offset: " ],
      input [
        id "offset",
        type' "number",
        value (toString model.offset),
        onInput address Offset
      ] [],
      label [ for "limit" ] [ text "Limit: " ],
      input [
        id "limit",
        type' "number",
        value (toString model.limit),
        onInput address Limit
      ] [],
      button [ class "signup-button", onClick address Query ] [ text "Query" ]
    ],
    case model.results of
      Nothing -> text "Please make a query"
      Just (Ok results) -> renderTable results
      Just (Err err) -> text ("Error: " ++ (case err of
        Http.Timeout -> "Timeout"
        Http.NetworkError -> "Network Error"
        Http.UnexpectedPayload err -> "Unexpected Payload: " ++ err
        Http.BadResponse code message -> "Bad Response: " ++ (toString code) ++ " " ++ message
      ))
  ]
-- EFFECTS --

decode : Decode.Decoder Results
decode = Decode.tuple3 (,,)
  (Decode.tuple2 (,) Decode.string Decode.string)
  (Decode.list (Decode.tuple2 (,) Decode.string Decode.string))
  (Decode.tuple3 (,,) Decode.int Decode.int Decode.int)

doQuery: String -> Int -> Int -> Effects Action
doQuery hostname offset limit =
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
