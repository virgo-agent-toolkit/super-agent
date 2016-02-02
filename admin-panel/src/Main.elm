import Html exposing (div, button, text)
import Html.Events exposing (onClick)
import StartApp.Simple as StartApp
import SuperAgent exposing (..)

main: Signal Html.Html
main =
  StartApp.start { model = model, view = view, update = update }

-- PORTS

port initialLocation : String -- incoming
port location : Signal String -- outgoing

-- MODEL

type Listing a = Listing
  { entries: List (String, a)
  , filter: String
  , offset: Int
  , limit: Int
  , current: Maybe a
  }

type Model
  = Loading
  | Overview
    { aepRows: Int
    }
  | AepListing (Listing Aep)

model: Model
model = Loading

-- UPDATE

type Action = NoOp

update: Action -> Model -> Model
update action model =
  case action of
    NoOp -> model

-- VIEW

view: Signal.Address Action -> Model -> Html.Html
view address model =
  case model of
    Loading -> text "Loading..."

    Overview data -> text "TODO: render Overview"

    AepListing list -> text "TODO: render AepListing"
