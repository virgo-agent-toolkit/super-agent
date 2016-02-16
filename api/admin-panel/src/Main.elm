import Html exposing (div, button, text)
import Html.Events exposing (onClick)
import StartApp as StartApp
import Native.Rpc
import Task exposing (Task, andThen)
import Effects exposing (Effects)

app: StartApp.App Model
app = StartApp.start
  { init = init
  , update = update
  , view = view
  , inputs = []
  }

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
  | ViewAep String

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

type Mode
  = Overview
  | Aep {
    hostname: String,
    stats: Stats,
    results: List AepRow
  }



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
    _ -> ({ model | loading = Just action }, Effects.none)
