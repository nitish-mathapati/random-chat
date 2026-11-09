
import pool from '../config/database.js';
import { emitToGuest } from './socket.service.js';

export type MatchmakingResult =
  | {
      status: 'waiting';
      queueId: string;
      message: string;
    }
  | {
      status: 'matched';
      matchId: string;
      partnerGuestId: string;
      message: string;
    }
  | {
      status: 'already_matched';
      matchId: string;
      partnerGuestId: string;
      message: string;
    };

export type ChatMode = 'text' | 'video';

export const isChatMode = (value: unknown): value is ChatMode =>
  value === 'text' || value === 'video';

export const joinMatchmakingQueue = async (
  guestId: string,
  chatMode: ChatMode
): Promise<MatchmakingResult> => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Serialize matchmaking operations to avoid matching one guest twice.
    await client.query(
      'SELECT pg_advisory_xact_lock($1)',
      [20261031]
    );

    // Confirm that this guest session is still valid.
    const guestResult = await client.query(
      `SELECT guest_id
       FROM guest_sessions
       WHERE guest_id = $1
         AND expires_at > NOW()
         AND revoked_at IS NULL`,
      [guestId]
    );

    if (guestResult.rowCount === 0) {
      throw new Error('GUEST_SESSION_INVALID');
    }

    // Check whether this guest already has an active match.
    const activeMatchResult = await client.query(
      `SELECT id, guest_one_id, guest_two_id
       FROM matchmaking_matches
       WHERE status = 'active'
         AND (guest_one_id = $1 OR guest_two_id = $1)
       LIMIT 1`,
      [guestId]
    );

    if (activeMatchResult.rows.length > 0) {
      const match = activeMatchResult.rows[0];

      const partnerGuestId =
        match.guest_one_id === guestId
          ? match.guest_two_id
          : match.guest_one_id;

      await client.query('COMMIT');

      return {
        status: 'already_matched',
        matchId: match.id,
        partnerGuestId,
        message: 'You are already in an active match.',
      };
    }

    // Remove expired or revoked guests from the waiting queue.
    await client.query(
      `UPDATE matchmaking_queue AS queue
       SET status = 'cancelled',
           cancelled_at = NOW()
       WHERE queue.status = 'waiting'
         AND NOT EXISTS (
           SELECT 1
           FROM guest_sessions AS guest
           WHERE guest.guest_id = queue.guest_id
             AND guest.expires_at > NOW()
             AND guest.revoked_at IS NULL
         )`
    );

    // Check whether this guest is already waiting.
    const existingQueueResult = await client.query(
      `SELECT id, chat_mode
       FROM matchmaking_queue
       WHERE guest_id = $1
         AND status = 'waiting'
       LIMIT 1`,
      [guestId]
    );

    if (existingQueueResult.rows.length > 0) {
      const existing = existingQueueResult.rows[0];

      if (existing.chat_mode === chatMode) {
        await client.query('COMMIT');

        return {
          status: 'waiting',
          queueId: existing.id,
          message: 'You are already waiting for a match.',
        };
      }

      // The guest switched modes; drop the old entry and search again.
      await client.query(
        `UPDATE matchmaking_queue
         SET status = 'cancelled',
             cancelled_at = NOW()
         WHERE id = $1`,
        [existing.id]
      );
    }

    // Find the oldest valid guest waiting in the same chat mode.
    const waitingGuestResult = await client.query(
      `SELECT queue.id AS queue_id, queue.guest_id
       FROM matchmaking_queue AS queue
       INNER JOIN guest_sessions AS guest
         ON guest.guest_id = queue.guest_id
       WHERE queue.status = 'waiting'
         AND queue.chat_mode = $2
         AND queue.guest_id <> $1
         AND guest.expires_at > NOW()
         AND guest.revoked_at IS NULL
       ORDER BY queue.queued_at ASC
       LIMIT 1
       FOR UPDATE OF queue`,
      [guestId, chatMode]
    );

    // Nobody is waiting. Add this guest to the queue.
    if (waitingGuestResult.rows.length === 0) {
      const queueResult = await client.query(
        `INSERT INTO matchmaking_queue (guest_id, chat_mode)
         VALUES ($1, $2)
         RETURNING id`,
        [guestId, chatMode]
      );

      await client.query('COMMIT');

      return {
        status: 'waiting',
        queueId: queueResult.rows[0].id,
        message: 'You have been added to the matchmaking queue.',
      };
    }

    // A waiting guest was found. Create a match.
    const waitingGuest = waitingGuestResult.rows[0];

    const matchResult = await client.query(
      `INSERT INTO matchmaking_matches (
         guest_one_id,
         guest_two_id,
         chat_mode
       )
       VALUES ($1, $2, $3)
       RETURNING id`,
      [waitingGuest.guest_id, guestId, chatMode]
    );

    const matchId = matchResult.rows[0].id;

    // Mark the waiting guest's queue entry as matched.
    await client.query(
      `UPDATE matchmaking_queue
       SET status = 'matched',
           matched_at = NOW()
       WHERE id = $1`,
      [waitingGuest.queue_id]
    );

    // Commit the database transaction before sending notifications.
    await client.query('COMMIT');

    // Notify the guest who was already waiting.
    emitToGuest(waitingGuest.guest_id, 'match_found', {
      matchId,
      partnerGuestId: guestId,
    });

    // Notify the guest who just joined.
    emitToGuest(guestId, 'match_found', {
      matchId,
      partnerGuestId: waitingGuest.guest_id,
    });

    console.log(`[Matchmaking] Match created: ${matchId}`);
    console.log(
      `[Matchmaking] Guests notified: ${waitingGuest.guest_id}, ${guestId}`
    );

    return {
      status: 'matched',
      matchId,
      partnerGuestId: waitingGuest.guest_id,
      message: 'A stranger has been found!',
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

export const cancelMatchmakingQueue = async (
  guestId: string
): Promise<boolean> => {
  const result = await pool.query(
    `UPDATE matchmaking_queue
     SET status = 'cancelled',
         cancelled_at = NOW()
     WHERE guest_id = $1
       AND status = 'waiting'
     RETURNING id`,
    [guestId]
  );

  return (result.rowCount ?? 0) > 0;
};

export const getMatchmakingStatus = async (
  guestId: string
): Promise<MatchmakingResult | {
  status: 'not_searching';
  message: string;
}> => {
  // First, check whether the guest has an active match.
  const matchResult = await pool.query(
    `SELECT id, guest_one_id, guest_two_id
     FROM matchmaking_matches
     WHERE status = 'active'
       AND (guest_one_id = $1 OR guest_two_id = $1)
     LIMIT 1`,
    [guestId]
  );

  if (matchResult.rows.length > 0) {
    const match = matchResult.rows[0];

    const partnerGuestId =
      match.guest_one_id === guestId
        ? match.guest_two_id
        : match.guest_one_id;

    return {
      status: 'matched',
      matchId: match.id,
      partnerGuestId,
      message: 'A stranger has been found!',
    };
  }

  // Otherwise, check whether the guest is waiting.
  const queueResult = await pool.query(
    `SELECT id
     FROM matchmaking_queue
     WHERE guest_id = $1
       AND status = 'waiting'
     LIMIT 1`,
    [guestId]
  );

  if (queueResult.rows.length > 0) {
    return {
      status: 'waiting',
      queueId: queueResult.rows[0].id,
      message: 'You are still waiting for a stranger.',
    };
  }

  return {
    status: 'not_searching',
    message: 'You are not currently searching for a stranger.',
  };
};
