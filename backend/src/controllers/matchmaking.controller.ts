import type { Request, Response } from 'express';

import {
  joinMatchmakingQueue,
  cancelMatchmakingQueue,
  getMatchmakingStatus
} from '../services/matchmaking.service.js';

export const joinMatchmaking = async (
  request: Request,
  response: Response
): Promise<void> => {
  try {
    // Guest ID comes from the authentication middleware.
    const guestId = response.locals.guestId as string;

    const result = await joinMatchmakingQueue(guestId);

    response.status(200).json({
      status: 'success',
      data: result,
    });
  } catch (error) {
    if (
      error instanceof Error &&
      error.message === 'GUEST_SESSION_INVALID'
    ) {
      response.status(401).json({
        status: 'error',
        message: 'Guest session is invalid or expired.',
      });
      return;
    }

    console.error('Join matchmaking error:', error);

    response.status(500).json({
      status: 'error',
      message: 'Unable to join matchmaking.',
    });
  }
};

export const cancelMatchmaking = async (
  request: Request,
  response: Response
): Promise<void> => {
  try {
    const guestId = response.locals.guestId as string;

    const cancelled = await cancelMatchmakingQueue(guestId);

    response.status(200).json({
      status: 'success',
      data: {
        cancelled,
        message: cancelled
          ? 'Matchmaking cancelled successfully.'
          : 'No active matchmaking request was found.',
      },
    });
  } catch (error) {
    console.error('Cancel matchmaking error:', error);

    response.status(500).json({
      status: 'error',
      message: 'Unable to cancel matchmaking.',
    });
  }
};

export const getMatchmakingStatusController = async (
  request: Request,
  response: Response
): Promise<void> => {
  try {
    const guestId = response.locals.guestId as string;

    const result = await getMatchmakingStatus(guestId);

    response.status(200).json({
      status: 'success',
      data: result,
    });
  } catch (error) {
    console.error('Get matchmaking status error:', error);

    response.status(500).json({
      status: 'error',
      message: 'Unable to retrieve matchmaking status.',
    });
  }
};