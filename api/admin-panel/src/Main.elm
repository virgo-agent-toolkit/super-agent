import Html exposing (div, button, text)
import Html.Events exposing (onClick)
import StartApp as StartApp
import Native.Rpc
import Task exposing (Task, andThen)
import Effects exposing (Effects, Never)
import Json.Decode as Json exposing ((:=))
import Http

app: StartApp.App Model
app = StartApp.start
  { init = init
  , update = update
  , view = view
  , inputs = []
  }

port tasks : Signal (Task.Task Never ())
port tasks =
  app.tasks

type alias Model =
  { mode: Mode
  , loading: Maybe Action
  }

type Action
  = QueryAep
    { hostname: String
    , offset: Int
    , limit: Int
    }
  | AepResults (Maybe String)

init : (Model, Effects Action)
init = ({ mode = Overview , loading = Nothing }, Effects.none)

---------------------------


call : a -> Task x ()
call value =
  Native.Rpc.call (toString value)


port runner : Task x ()
port runner =
  call "foo"

main: Signal Html.Html
main = app.html

type alias Stats =
  { offset: Int
  , limit: Int
  , total: Int
  }

type alias AepRow =
  { id: String
  , hostname: String
  }

type alias AepResult =
  { hostname: String
  , stats: Stats
  , results: List AepRow
  }
type alias AepQuery =
  { hostname: String
  , offset: Int
  , limit: Int
  }

type Mode
  = Overview
  | Aep AepResult



view: Signal.Address Action -> Model -> Html.Html
view address model =
  case model.mode of
    Overview -> button [onClick address (QueryAep
      { hostname = ""
      , offset = 0
      , limit = 20
      })] [ text "AEP" ]
    Aep query -> text "TODO: render me"


update: Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    QueryAep params ->
      ( { model | loading = Just action }
      , queryAep params
      )
    AepResults str -> ( model, Effects.none)


queryAep : AepQuery -> Effects Action
queryAep query =
  Http.get decodeUrl (randomUrl "test")
    |> Task.toMaybe
    |> Task.map AepResults
    |> Effects.task

(=>): a -> b -> (a, b)
(=>) = (,)

randomUrl : String -> String
randomUrl topic =
  Http.url "http://api.giphy.com/v1/gifs/random"
    [ "api_key" => "dc6zaTOxFJmzC"
    , "tag" => topic
    ]


decodeUrl : Json.Decoder String
decodeUrl =
  Json.at ["data", "image_url"] Json.string
