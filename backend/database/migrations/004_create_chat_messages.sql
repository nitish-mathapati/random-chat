
-- Stores messages exchanged between matched guests.
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    match_id UUID NOT NULL
        REFERENCES matchmaking_matches(id)
        ON DELETE CASCADE,

    sender_guest_id UUID NOT NULL
        REFERENCES guest_sessions(guest_id)
        ON DELETE CASCADE,

    message TEXT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_chat_message_not_empty
        CHECK (LENGTH(TRIM(message)) > 0),

    CONSTRAINT chk_chat_message_max_length
        CHECK (LENGTH(message) <= 2000)
);

-- Helps retrieve messages belonging to a match in chronological order.
CREATE INDEX idx_chat_messages_match_created
ON chat_messages(match_id, created_at, id);

-- Helps retrieve messages sent by a particular guest.
CREATE INDEX idx_chat_messages_sender
ON chat_messages(sender_guest_id);
