
import pool from '../config/database.js';

export interface SavedMessage {
  id: string;
  matchId: string;
  senderGuestId: string;
  message: string;
  createdAt: Date;
  partnerGuestId: string;
}

export interface ChatMessage {
  id: string;
  matchId: string;
  senderGuestId: string;
  message: string;
  createdAt: Date;
}

/**
 * Save a message after verifying that:
 * 1. The match exists and is active.
 * 2. The sender belongs to that match.
 * 3. The message is not empty and does not exceed 2000 characters.
 */
export const saveMessage = async (
  matchId: string,
  senderGuestId: string,
  message: string
): Promise<SavedMessage> => {
  const trimmedMessage = message.trim();

  if (!trimmedMessage) {
    throw new Error('MESSAGE_EMPTY');
  }

  if (trimmedMessage.length > 2000) {
    throw new Error('MESSAGE_TOO_LONG');
  }

  const result = await pool.query(
    `WITH eligible_match AS (
       SELECT
         id,
         CASE
           WHEN guest_one_id = $2 THEN guest_two_id
           ELSE guest_one_id
         END AS partner_guest_id
       FROM matchmaking_matches
       WHERE id = $1
         AND status = 'active'
         AND (guest_one_id = $2 OR guest_two_id = $2)
     ),
     inserted_message AS (
       INSERT INTO chat_messages (
         match_id,
         sender_guest_id,
         message
       )
       SELECT
         id,
         $2,
         $3
       FROM eligible_match
       RETURNING
         id,
         match_id,
         sender_guest_id,
         message,
         created_at
     )
     SELECT
       inserted_message.id,
       inserted_message.match_id,
       inserted_message.sender_guest_id,
       inserted_message.message,
       inserted_message.created_at,
       eligible_match.partner_guest_id
     FROM inserted_message
     INNER JOIN eligible_match
       ON eligible_match.id = inserted_message.match_id`,
    [matchId, senderGuestId, trimmedMessage]
  );

  if (result.rows.length === 0) {
    throw new Error('MATCH_NOT_ACTIVE_OR_UNAUTHORIZED');
  }

  const row = result.rows[0];

  return {
    id: row.id,
    matchId: row.match_id,
    senderGuestId: row.sender_guest_id,
    message: row.message,
    createdAt: row.created_at,
    partnerGuestId: row.partner_guest_id,
  };
};

/**
 * Retrieve the latest messages from an active match.
 * Only participants can access their conversation.
 */
export const getChatHistory = async (
  matchId: string,
  guestId: string,
  requestedLimit = 50
): Promise<ChatMessage[]> => {
  const limit = Math.min(Math.max(requestedLimit, 1), 100);

  // Verify that this guest belongs to an active match.
  const matchResult = await pool.query(
    `SELECT id
     FROM matchmaking_matches
     WHERE id = $1
       AND status = 'active'
       AND (guest_one_id = $2 OR guest_two_id = $2)
     LIMIT 1`,
    [matchId, guestId]
  );

  if (matchResult.rows.length === 0) {
    throw new Error('MATCH_NOT_ACTIVE_OR_UNAUTHORIZED');
  }

  // Retrieve the latest messages.
  const messageResult = await pool.query(
    `SELECT
       id,
       match_id,
       sender_guest_id,
       message,
       created_at
     FROM chat_messages
     WHERE match_id = $1
     ORDER BY created_at DESC, id DESC
     LIMIT $2`,
    [matchId, limit]
  );

  // Return messages in chronological order.
  return messageResult.rows.reverse().map((row) => ({
    id: row.id,
    matchId: row.match_id,
    senderGuestId: row.sender_guest_id,
    message: row.message,
    createdAt: row.created_at,
  }));
};
