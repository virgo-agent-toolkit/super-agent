import Html exposing (div, button, text)
import Html.Events exposing (onClick)
import StartApp.Simple as StartApp

main: Signal Html.Html
main =
  StartApp.start { model = model, view = view, update = update }

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

type alias Model =
  { mode: Mode
  , loading: Maybe Action
  }

model: Model
model =
  { mode = Overview
  , loading = Nothing
  }

type Action
  = QueryAep
    { hostname: String
    , offset: Int
    , limit: Int
    }
  | ViewAep String


view: Signal.Address Action -> Model -> Html.Html
view address model =
  case model.mode of
    Overview -> button [onClick address (QueryAep
      { hostname = ""
      , offset = 0
      , limit = 20
      })] [ text "AEP" ]
    Aep query -> text "TODO: render me"


update: Action -> Model -> Model
update action model =
  case action of
    _ -> { model | loading = Just action }
