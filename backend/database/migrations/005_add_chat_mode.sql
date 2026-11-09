
-- Guests are only matched with others who chose the same chat mode.
ALTER TABLE matchmaking_queue
    ADD COLUMN chat_mode VARCHAR(10) NOT NULL DEFAULT 'text',
    ADD CONSTRAINT chk_matchmaking_queue_chat_mode
        CHECK (chat_mode IN ('text', 'video'));

ALTER TABLE matchmaking_matches
    ADD COLUMN chat_mode VARCHAR(10) NOT NULL DEFAULT 'text',
    ADD CONSTRAINT chk_match_chat_mode
        CHECK (chat_mode IN ('text', 'video'));

DROP INDEX IF EXISTS idx_matchmaking_waiting_queue;

CREATE INDEX idx_matchmaking_waiting_queue
ON matchmaking_queue(chat_mode, queued_at)
WHERE status = 'waiting';
