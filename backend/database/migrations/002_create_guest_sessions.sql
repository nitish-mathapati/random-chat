-- Store temporary guest sessions
CREATE TABLE guest_sessions (
    guest_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    token_hash CHAR(64) NOT NULL UNIQUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    expires_at TIMESTAMPTZ NOT NULL,

    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    revoked_at TIMESTAMPTZ,

    CONSTRAINT chk_guest_session_expiry
        CHECK (expires_at > created_at)
);

-- Find sessions by expiration time
CREATE INDEX idx_guest_sessions_expires_at
ON guest_sessions(expires_at);

-- Find active sessions efficiently
CREATE INDEX idx_guest_sessions_active
ON guest_sessions(guest_id)
WHERE revoked_at IS NULL;