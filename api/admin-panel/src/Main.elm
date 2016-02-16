import Html exposing (form,h1,text,label,input,div,button)
import Html.Events exposing (onClick)
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
  }

type alias Columns = List String
type alias Rows = List (List String)
type alias Stats = (Int, Int, Int)
type alias Results = (Columns, Rows, Stats)


init : (Model, Effects Action)
init = ({hostname="",offset=0,limit=20}, Effects.none)

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
    _ ->
       (model, Effects.none)

-- VIEW --

view: Signal.Address Action -> Model -> Html.Html
view address model =
  div [ id "signup-form" ] [
    h1 [] [ text "AEP Query" ],
    label [ for "hostname" ] [ text "Hostname: " ],
    input [ id "hostname", type' "text", value model.hostname ] [],
    label [ for "offset" ] [ text "Offset: " ],
    input [ id "offset", type' "number", value (toString model.offset) ] [],
    label [ for "limit" ] [ text "Limit: " ],
    input [ id "limit", type' "number", value (toString model.limit) ] [],
    button [ class "signup-button", onClick address Query ] [ text "Query" ]
  ]

-- EFFECTS --

decode : Decode.Decoder Results
decode = Decode.tuple3 (,,)
  (Decode.list Decode.string)
  (Decode.list (Decode.list Decode.string))
  (Decode.tuple3 (,,) Decode.int Decode.int Decode.int)

doQuery: String -> Int -> Int -> Effects Action
doQuery hostname offset limit =
  let task =
    Encode.list [Encode.object[
      ("hostname",Encode.string hostname),
      ("offset",Encode.int offset),
      ("limit",Encode.int limit)
    ]]
      |> Encode.encode 0
      |> Http.string
      |> Http.post decode "http://localhost:8080/api/aep.query"
  in
    task
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
