import { createHash } from 'node:crypto';
import type { Request, Response, NextFunction } from 'express';
import type { RequestHandler } from 'express';
import pool from '../config/database.js';

const guestAuthMiddleware: RequestHandler = async (
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authorization = request.header('Authorization');

    if (!authorization || !authorization.startsWith('Bearer ')) {
      response.status(401).json({
        status: 'error',
        message: 'Guest session token is required.',
      });
      return;
    }

    const sessionToken = authorization.substring(7);

    if (!/^[A-Za-z0-9_-]{43}$/.test(sessionToken)) {
      response.status(401).json({
        status: 'error',
        message: 'Invalid guest session token.',
      });
      return;
    }

    // Hash the supplied token before checking the database.
    const tokenHash = createHash('sha256')
      .update(sessionToken)
      .digest('hex');

    // Verify the session and update its last activity time.
    const result = await pool.query(
      `UPDATE guest_sessions
       SET last_seen_at = NOW()
       WHERE token_hash = $1
         AND expires_at > NOW()
         AND revoked_at IS NULL
       RETURNING guest_id`,
      [tokenHash]
    );

    if (result.rows.length === 0) {
      response.status(401).json({
        status: 'error',
        message: 'Guest session is invalid, expired, or revoked.',
      });
      return;
    }

    // Store the authenticated guest ID for the controller.
    response.locals.guestId = result.rows[0].guest_id as string;

    next();
  } catch (error) {
    console.error('Guest authentication error:', error);

    response.status(500).json({
      status: 'error',
      message: 'Unable to authenticate guest session.',
    });
  }
};

export default guestAuthMiddleware;