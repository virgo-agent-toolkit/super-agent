DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;
COMMENT ON SCHEMA public IS 'standard public schema';

CREATE TABLE aep (
    id uuid PRIMARY KEY,
    hostname text NOT NULL
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
    name text NOT NULL,
    aep_id uuid REFERENCES aep(id) ON DELETE SET NULL,
    token uuid REFERENCES token(id) ON DELETE SET NULL
);
CREATE TABLE event (
    "timestamp" TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    event json NOT NULL
);

CREATE INDEX event_idx ON events ("timestamp" DESC);

-- These indexes makes it fast to look up all tokens/agents for a particular account.
CREATE INDEX agent_account_idx ON agent (account_id);
CREATE INDEX token_account_idx ON token (account_id);
