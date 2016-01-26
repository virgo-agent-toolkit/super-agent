DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;
COMMENT ON SCHEMA public IS 'standard public schema';

CREATE TABLE aep (
    id uuid PRIMARY KEY,
    address text NOT NULL
);
CREATE TABLE account (
    id uuid PRIMARY KEY,
    name text NOT NULL
);
CREATE TABLE token (
    id uuid PRIMARY KEY,
    account_id uuid REFERENCES account(id) ON DELETE CASCADE NOT NULL,
    description text NOT NULL
);
CREATE TABLE agent (
    id uuid PRIMARY KEY,
    account_id uuid REFERENCES account(id) ON DELETE CASCADE NOT NULL,
    description text NOT NULL
);
CREATE TABLE connection (
    aep_id uuid REFERENCES aep(id) ON DELETE CASCADE NOT NULL,
    agent_id uuid REFERENCES agent(id) ON DELETE CASCADE NOT NULL,
    connect timestamp without time zone DEFAULT now() NOT NULL,
    disconnect timestamp without time zone
);

-- This index makes it fast to find the latest connection for a particular agent.
-- The order here matters a lot!  I tried with connect first and it's super slow on most queries.
CREATE INDEX agent_connection_idx ON connection (agent_id, connect DESC);

-- These indexes makes it fast to look up all tokens/agents for a particular account.
CREATE INDEX agent_account_idx ON agent (account_id);
CREATE INDEX token_account_idx ON token (account_id);
