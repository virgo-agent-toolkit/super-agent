module SuperAgent(Aep, Account, Agent, Token, Event, Id, toId, fromId) where

{-| Super Agent System

# Models
@docs Aep, Account, Agent, Token, Event

# Common Helpers
@docs Id, toId, fromId


-}

import Json.Encode exposing (Value)

{-| Type for validated IDs
-}
type Id = Id String

{-| Validate a string to be used as a UUID

    id = "318d1379-e40c-4669-b3dd-e6efaffe69bc"
    toId id == Ok (Id id)
    toId "bad" == Err "could not convert string 'bad' to an Id"
-}
toId: String -> Result String Id
toId str = Ok (Id str) -- TODO: validate input

{-| Unwrap an ID back to a plain string

    str = fromId id
-}
fromId: Id -> String
fromId (Id str) = str

{-| Model for a deployed agent endpoint.
-}
type alias Aep =
  { id: Id
  , hostname: String
  }

{-| Model for a user account.
-}
type alias Account =
  { id: Id
  , name: String
  }

{-| Model for a deployed agent.
-}
type alias Agent =
  { id: Id
  , account_id: Id
  , name: String
  , aep_id: Maybe String
  , token: Maybe Id
  }

{-| Model for an agent authentication token.
-}
type alias Token =
  { id: Id
  , account_id: Id
  , description: String
  }

{-| Model for arbitrary logged events with timestamp.
-}
type alias Event =
  { timestamp: Int
  , event: Value
  }
  
