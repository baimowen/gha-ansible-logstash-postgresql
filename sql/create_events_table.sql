-- Create the events table used by Logstash JDBC output.
-- Run this against the PostgreSQL container (e.g. via psql or pgAdmin).
-- Ensure the PostgreSQL service is running and accessible with the credentials
-- defined in .env (POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB).

-- If the table already exists, re-running this script is idempotent because
-- we use CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message TEXT NOT NULL,
    received_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    source TEXT,           -- optional: e.g. "filebeat", "nginx", "systemd"
    tags TEXT[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Optional: create an index for time‑based queries
CREATE INDEX IF NOT EXISTS idx_events_received_at ON events (received_at DESC);

-- Optional: grant permissions if the logstash user is not the owner
-- GRANT ALL PRIVILEGES ON events TO ${POSTGRES_USER:-logstash};