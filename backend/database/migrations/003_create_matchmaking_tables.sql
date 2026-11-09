
-- Stores guests waiting for a random match.
CREATE TABLE matchmaking_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    guest_id UUID NOT NULL
        REFERENCES guest_sessions(guest_id)
        ON DELETE CASCADE,

    status VARCHAR(20) NOT NULL DEFAULT 'waiting',

    queued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    matched_at TIMESTAMPTZ,

    cancelled_at TIMESTAMPTZ,

    CONSTRAINT chk_matchmaking_queue_status
        CHECK (status IN ('waiting', 'matched', 'cancelled')),

    CONSTRAINT uq_matchmaking_queue_id_guest
        UNIQUE (id, guest_id)
);

-- A guest can have only one waiting queue entry.
CREATE UNIQUE INDEX idx_matchmaking_one_waiting_per_guest
ON matchmaking_queue(guest_id)
WHERE status = 'waiting';

-- Helps find waiting guests in queue order.
CREATE INDEX idx_matchmaking_waiting_queue
ON matchmaking_queue(queued_at)
WHERE status = 'waiting';


-- Stores successfully created matches.
CREATE TABLE matchmaking_matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    guest_one_id UUID NOT NULL
        REFERENCES guest_sessions(guest_id)
        ON DELETE CASCADE,

    guest_two_id UUID NOT NULL
        REFERENCES guest_sessions(guest_id)
        ON DELETE CASCADE,

    status VARCHAR(20) NOT NULL DEFAULT 'active',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    ended_at TIMESTAMPTZ,

    CONSTRAINT chk_match_different_guests
        CHECK (guest_one_id <> guest_two_id),

    CONSTRAINT chk_match_status
        CHECK (status IN ('active', 'ended'))
);

-- Prevent a guest from participating in multiple active matches.
CREATE UNIQUE INDEX idx_match_active_guest_one
ON matchmaking_matches(guest_one_id)
WHERE status = 'active';

CREATE UNIQUE INDEX idx_match_active_guest_two
ON matchmaking_matches(guest_two_id)
WHERE status = 'active';

-- Prevent duplicate active matches with reversed participant order.
CREATE UNIQUE INDEX idx_match_active_guest_pair
ON matchmaking_matches(
    LEAST(guest_one_id, guest_two_id),
    GREATEST(guest_one_id, guest_two_id)
)
WHERE status = 'active';
