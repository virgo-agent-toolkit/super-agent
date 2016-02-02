module SuperAgent(Aep, Account, Agent, Token, Event) where

{-| Super Agent System

# Models
@docs Aep, Account, Agent, Token, Event

-}

import Json.Encode exposing (Value)

{-| Model for a deployed agent endpoint.
-}
type alias Aep =
  { hostname: String
  }

{-| Model for a user account.
-}
type alias Account =
  { name: String
  }

{-| Model for a deployed agent.
-}
type alias Agent =
  { account_id: String
  , name: String
  , aep_id: Maybe String
  , token: Maybe String
  }

{-| Model for an agent authentication token.
-}
type alias Token =
  { account_id: String
  , description: String
  }

{-| Model for arbitrary logged events with timestamp.
-}
type alias Event =
  { timestamp: Int
  , event: Value
  }
