
import cron from 'node-cron';

import pool from '../config/database.js';

// Delete expired and revoked guest sessions.
const cleanupExpiredGuestSessions = async (): Promise<void> => {
  try {
    const result = await pool.query(
      `DELETE FROM guest_sessions
       WHERE expires_at <= NOW()
          OR revoked_at IS NOT NULL`
    );

    console.log(
      `[Guest Cleanup] Deleted ${result.rowCount ?? 0} expired or revoked sessions.`
    );
  } catch (error) {
    console.error(
      '[Guest Cleanup] Failed to clean guest sessions:',
      error
    );
  }
};

// Start automatic guest session cleanup.
export const startGuestSessionCleanup = (): void => {
  console.log('[Guest Cleanup] Starting cleanup scheduler...');

  // Run cleanup immediately when the backend starts.
  void cleanupExpiredGuestSessions();

  // Run cleanup once every hour.
  cron.schedule('0 * * * *', async () => {
    console.log('[Guest Cleanup] Running scheduled cleanup...');

    await cleanupExpiredGuestSessions();
  });

  console.log(
    '[Guest Cleanup] Scheduler configured to run every hour.'
  );
};
