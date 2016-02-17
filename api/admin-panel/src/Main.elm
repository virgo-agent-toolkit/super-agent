module Main where

import Html exposing (form,div,ul,li,a,text,table,thead,tbody,tr,th,td,nav,button,span,label,input,h1)
import Html.Events exposing (onClick,on,targetValue)
import Html.Attributes as Attr exposing (class,href,for,id,type',value,placeholder,step,title,key)
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
init = let model = { hostname = ""
  , offset = 0
  , limit = 20
  , results = Nothing
  } in (model, doQuery model)

-- UPDATE --

type Action
  = Hostname String
  | Limit String
  | QueryResults (Result Http.Error Results)
  | Edit String
  | Delete String
  | Changed (Result Http.Error Bool)
  | Goto Int


update: Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    Hostname value -> let model = {model | hostname = value} in
      (model, doQuery model)
    Limit value ->
      case toInt value of
        Ok num -> let model = {model | limit = num} in
          (model, doQuery model)
        Err _ -> (model, Effects.none)
    QueryResults results ->
       ({model | results = Just results }, Effects.none)
    Edit id ->
      (model, Effects.none)
    Delete id ->
      (model, deleteNode id)
    Changed (Ok True) ->
      (model, doQuery model)
    Changed (Ok False) ->
      (model, Effects.none)
    Changed (Err err) ->
      ({model | results = Just(Err err)}, Effects.none)
    Goto page -> let model = { model | offset = page * model.limit } in
      (model, doQuery model)


-- VIEW --

onInput: Signal.Address Action -> (String -> Action) -> Html.Attribute
onInput address action =
  on "input" targetValue (\str -> Signal.message address (action str))

renderPagination: Signal.Address Action -> Stats -> Html.Html
renderPagination address (offset, limit, total) =
  let
    lastPage = total // limit
    currentPage = offset // limit
    startPage' = max 0 (currentPage - 7)
    endPage = min lastPage (startPage' + 14)
    startPage = max 0 (endPage - 14)
  in
    nav [] [
      ul [class "pagination"] (
        (if currentPage > 0 then
          li [key "left"] [a [
            href "javascript:void(0)",
            onClick address (Goto (currentPage - 1))
          ] [text "«"]]
        else
          li [key "left",class "disabled"] [
            a [href "javascript:void(0)"] [text "«"]
          ])
        ::
          (if currentPage < lastPage then
            li [key "right"] [a [
              href "javascript:void(0)",
              onClick address (Goto (currentPage + 1))
            ] [text "»"]]
          else
            li [key "right", class "disabled"] [
              a [href "javascript:void(0)"] [text "»"]
            ])
        ::
        List.map (\i ->
           li [key (toString i), class (if currentPage == i then "active" else "")] [
            a [
              href "javascript:void(0)",
              onClick address (Goto i)
            ] [i + 1 |> toString |> text]
          ]
        ) [startPage..endPage]
      )
    ]


renderTable: Signal.Address Action -> Columns -> Rows -> Html.Html
renderTable address columns rows =
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
    tr [] [
      th [] [ text (capitalize n1) ],
      th [] [ text (capitalize n2) ],
      th [] [ text "Actions"]
    ]
  ]

renderBody : Signal.Address Action -> Rows -> Html.Html
renderBody address rows =
  tbody [] (List.map (renderRow address) rows)

renderRow : Signal.Address Action -> Row -> Html.Html
renderRow address (id, hostname) =
  tr [key id] [
    td [] [ text id ],
    td [] [ text hostname ],
    td [] [
      div [class "btn-group"] [
        button [
          class "btn btn-default",
          onClick address (Edit id)
        ] [
          span [ class "glyphicon glyphicon-pencil"] [ ]
        ],
        button [
          class "btn btn-danger",
          onClick address (Delete id)
        ] [
          span [ class "glyphicon glyphicon-trash"] [ ]
        ]
      ]
    ]
  ]

renderForm : Signal.Address Action -> Model -> Html.Html
renderForm address model =
  form [ class "form-horizontal" ] [
    div [class "form-group"] [
      label [
        class "col-sm-3 control-label",
        for "hostname"
      ] [ text "Hostname" ],
      div [ class "col-sm-9" ] [
        input [
          class "form-control",
          id "hostname",
          type' "text",
          value model.hostname ,
          placeholder "Show All",
          onInput address Hostname
        ] []
      ]
    ],
    div [class "form-group"] [
      label [
        class "col-sm-3 control-label",
        for "limit"
      ] [ text "Results per Page: " ],
      div [ class "col-sm-9" ] [
        input [
          title (toString model.limit),
          class "form-control",
          id "limit",
          type' "range",
          Attr.min "10",
          Attr.max "100",
          step "10",
          value (toString model.limit),
          onInput address Limit
        ] []
      ]
    ]
  ]

view: Signal.Address Action -> Model -> Html.Html
view address model = div [] [
    div [ class "navbar navbar-default navbar-fixed-top"] [
      div [ class "container" ] [
        div [class "navbar-header"] [
          a [class "navbar-brand"] [text "Admin Panel"]
        ],
        div [class "navbar-collapse collapse"] [
          ul [class "nav navbar-nav"] [
            li [] [
              a [href "#"] [text "AEPs"]
            ]
          ]
        ]
      ]
    ],
    div [ class "container" ]
    [
      div [class "page-header"] [
        div [class "row"] [
          h1 [] [ text "Agent Endpoints" ]
        ]
      ],
      renderForm address model,
      case model.results of
        Nothing -> text "Loading..."
        Just (Ok (columns, rows, stats)) -> div [] [
          renderPagination address stats,
          renderTable address columns rows,
          renderPagination address stats
        ]
        Just (Err err) -> text ("Error: " ++ (case err of
          Http.Timeout -> "Timeout"
          Http.NetworkError -> "Network Error"
          Http.UnexpectedPayload err -> "Unexpected Payload: " ++ err
          Http.BadResponse code message -> "Bad Response: " ++ (toString code) ++ " " ++ message
        ))
    ]
  ]
-- EFFECTS --

doQuery: Model -> Effects Action
doQuery model =
  let
    decode = Decode.tuple3 (,,)
      (Decode.tuple2 (,) Decode.string Decode.string)
      (Decode.list (Decode.tuple2 (,) Decode.string Decode.string))
      (Decode.tuple3 (,,) Decode.int Decode.int Decode.int)
  in
    Encode.list [Encode.object[
      ("hostname",Encode.string ("*" ++ model.hostname ++ "*")),
      ("offset",Encode.int model.offset),
      ("limit",Encode.int model.limit)
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
