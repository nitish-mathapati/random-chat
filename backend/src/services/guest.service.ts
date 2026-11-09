
import { createHash, randomBytes } from 'node:crypto';

import pool from '../config/database.js';

// Guest sessions are valid for 24 hours.
const GUEST_SESSION_HOURS = 24;

interface GuestSession {
  guestId: string;
  sessionToken: string;
  createdAt: Date;
  expiresAt: Date;
}

// Generate a secure token and create a guest session.
export const createGuestSession = async (): Promise<GuestSession> => {
  // Generate 32 cryptographically secure random bytes.
  const sessionToken = randomBytes(32).toString('base64url');

  // Store only the SHA-256 hash in PostgreSQL.
  const tokenHash = createHash('sha256')
    .update(sessionToken)
    .digest('hex');

  const result = await pool.query(
    `INSERT INTO guest_sessions (
       token_hash,
       expires_at
     )
     VALUES (
       $1,
       NOW() + ($2 * INTERVAL '1 hour')
     )
     RETURNING
       guest_id,
       created_at,
       expires_at`,
    [tokenHash, GUEST_SESSION_HOURS]
  );

  const session = result.rows[0];

  // Return the original token only once.
  return {
    guestId: session.guest_id,
    sessionToken,
    createdAt: session.created_at,
    expiresAt: session.expires_at,
  };
};

// Restore an existing guest session using its original token.
export const restoreGuestSession = async (
  sessionToken: string
): Promise<Omit<GuestSession, 'sessionToken'> | null> => {
  // Calculate the SHA-256 hash of the supplied token.
  const tokenHash = createHash('sha256')
    .update(sessionToken)
    .digest('hex');

  // Find a valid, non-expired, non-revoked session.
  const result = await pool.query(
    `UPDATE guest_sessions
     SET last_seen_at = NOW()
     WHERE token_hash = $1
       AND expires_at > NOW()
       AND revoked_at IS NULL
     RETURNING guest_id, created_at, expires_at`,
    [tokenHash]
  );

  if (result.rowCount !== 1) {
    return null;
  }

  const session = result.rows[0];

  return {
    guestId: session.guest_id,
    createdAt: session.created_at,
    expiresAt: session.expires_at,
  };
};


// Revoke an existing guest session.
export const revokeGuestSession = async (
  sessionToken: string
): Promise<boolean> => {
  // Calculate the hash of the supplied session token.
  const tokenHash = createHash('sha256')
    .update(sessionToken)
    .digest('hex');

  // Revoke the session in PostgreSQL.
  const result = await pool.query(
    `UPDATE guest_sessions
     SET revoked_at = NOW()
     WHERE token_hash = $1
       AND revoked_at IS NULL
     RETURNING guest_id`,
    [tokenHash]
  );

  return result.rowCount === 1;
};
