
import type { Request, Response } from 'express';

import {
  createGuestSession,
  restoreGuestSession,
  revokeGuestSession,
} from '../services/guest.service.js';

export const createGuestSessionController = async (
  request: Request,
  response: Response
): Promise<void> => {
  try {
    const session = await createGuestSession();

    response.status(201).json({
      status: 'success',
      message: 'Guest session created successfully',
      data: session,
    });
  } catch (error) {
    console.error('Guest session creation failed:', error);

    response.status(500).json({
      status: 'error',
      message: 'Unable to create guest session',
    });
  }
};

export const restoreGuestSessionController = async (
  request: Request,
  response: Response
): Promise<void> => {
  try {
    const { sessionToken } = request.body;

    if (
      typeof sessionToken !== 'string' ||
      sessionToken.length !== 43
    ) {
      response.status(400).json({
        status: 'error',
        message: 'A valid session token is required',
      });
      return;
    }

    const session = await restoreGuestSession(sessionToken);

    if (!session) {
      response.status(401).json({
        status: 'error',
        message: 'Guest session is invalid or expired',
      });
      return;
    }

    response.status(200).json({
      status: 'success',
      message: 'Guest session restored successfully',
      data: session,
    });
  } catch (error) {
    console.error('Guest session restoration failed:', error);

    response.status(500).json({
      status: 'error',
      message: 'Unable to restore guest session',
    });
  }
};

export const logoutGuestSessionController = async (
  request: Request,
  response: Response
): Promise<void> => {
  try {
    const { sessionToken } = request.body;

    if (
      typeof sessionToken !== 'string' ||
      sessionToken.length !== 43
    ) {
      response.status(400).json({
        status: 'error',
        message: 'A valid session token is required',
      });
      return;
    }

    const revoked = await revokeGuestSession(sessionToken);

    if (!revoked) {
      response.status(401).json({
        status: 'error',
        message: 'Guest session is invalid or already revoked',
      });
      return;
    }

    response.status(200).json({
      status: 'success',
      message: 'Guest session logged out successfully',
    });
  } catch (error) {
    console.error('Guest logout failed:', error);

    response.status(500).json({
      status: 'error',
      message: 'Unable to logout guest session',
    });
  }
};
