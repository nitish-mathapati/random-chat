
import { createHash } from 'node:crypto';
import type { Server as HttpServer } from 'node:http';
import {
  Server,
  type Socket,
} from 'socket.io';

import pool from '../config/database.js';
import {
  saveMessage,
  getChatHistory,
} from './message.service.js';

interface GuestSocketData {
  guestId: string;
}

interface SessionDescriptionPayload {
  sdp: string;
  type: 'offer' | 'answer';
}

interface IceCandidatePayload {
  candidate: string;
  sdpMid: string | null;
  sdpMLineIndex: number | null;
}

interface WebRtcSignalError {
  message: string;
}

interface ChatMessage {
  id: string;
  matchId: string;
  senderGuestId: string;
  message: string;
  createdAt: Date;
}

interface ClientToServerEvents {
  send_message: (payload: {
    matchId: string;
    message: string;
  }) => void;

  get_chat_history: (payload: {
    matchId: string;
    limit?: number;
  }) => void;

  end_match: (payload: {
    matchId: string;
  }) => void;

  webrtc_offer: (payload: {
    matchId: string;
    description: SessionDescriptionPayload;
  }) => void;

  webrtc_answer: (payload: {
    matchId: string;
    description: SessionDescriptionPayload;
  }) => void;

  webrtc_ice_candidate: (payload: {
    matchId: string;
    candidate: IceCandidatePayload;
  }) => void;
}

interface ServerToClientEvents {
  match_found: (payload: {
    matchId: string;
    partnerGuestId: string;
  }) => void;

  match_ended: (payload: {
    matchId: string;
    endedByGuestId: string;
  }) => void;

  new_message: (payload: ChatMessage) => void;

  message_error: (payload: {
    message: string;
  }) => void;

  chat_history: (payload: {
    matchId: string;
    messages: ChatMessage[];
  }) => void;

  webrtc_offer: (payload: {
    matchId: string;
    fromGuestId: string;
    description: SessionDescriptionPayload;
  }) => void;

  webrtc_answer: (payload: {
    matchId: string;
    fromGuestId: string;
    description: SessionDescriptionPayload;
  }) => void;

  webrtc_ice_candidate: (payload: {
    matchId: string;
    fromGuestId: string;
    candidate: IceCandidatePayload;
  }) => void;

  webrtc_signal_error: (payload: WebRtcSignalError) => void;
}

type GuestSocket = Socket<
  ClientToServerEvents,
  ServerToClientEvents,
  Record<string, never>,
  GuestSocketData
>;

type GuestSocketServer = Server<
  ClientToServerEvents,
  ServerToClientEvents,
  Record<string, never>,
  GuestSocketData
>;

let io: GuestSocketServer | null = null;

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

// Only these error codes are safe to show to clients; anything else may leak database details.
const CLIENT_SAFE_ERRORS = new Set([
  'MESSAGE_EMPTY',
  'MESSAGE_TOO_LONG',
  'MATCH_NOT_ACTIVE_OR_UNAUTHORIZED',
]);

function toClientError(error: unknown, fallback: string): string {
  return error instanceof Error && CLIENT_SAFE_ERRORS.has(error.message)
    ? error.message
    : fallback;
}

function createSocketRateLimiter(maxEvents: number, windowMs: number) {
  let count = 0;
  let windowStart = Date.now();

  return (): boolean => {
    const now = Date.now();

    if (now - windowStart >= windowMs) {
      windowStart = now;
      count = 0;
    }

    count += 1;
    return count > maxEvents;
  };
}

function isValidMatchId(matchId: unknown): matchId is string {
  return (
    typeof matchId === 'string' &&
    UUID_REGEX.test(matchId)
  );
}

function isValidDescription(
  description: unknown,
  expectedType: 'offer' | 'answer'
): description is SessionDescriptionPayload {
  if (
    typeof description !== 'object' ||
    description === null
  ) {
    return false;
  }

  const value = description as Record<string, unknown>;

  return (
    typeof value.sdp === 'string' &&
    value.sdp.length > 0 &&
    value.sdp.length <= 100_000 &&
    value.type === expectedType
  );
}

function isValidIceCandidate(
  candidate: unknown
): candidate is IceCandidatePayload {
  if (
    typeof candidate !== 'object' ||
    candidate === null
  ) {
    return false;
  }

  const value = candidate as Record<string, unknown>;

  const validSdpMid =
    value.sdpMid === null ||
    (
      typeof value.sdpMid === 'string' &&
      value.sdpMid.length <= 256
    );

  const validSdpMLineIndex =
    value.sdpMLineIndex === null ||
    (
      typeof value.sdpMLineIndex === 'number' &&
      Number.isInteger(value.sdpMLineIndex) &&
      value.sdpMLineIndex >= 0
    );

  return (
    typeof value.candidate === 'string' &&
    value.candidate.length > 0 &&
    value.candidate.length <= 4096 &&
    validSdpMid &&
    validSdpMLineIndex
  );
}

// Find the other participant of an active match.
// The recipient is always obtained from the database.
async function getActiveMatchPartner(
  matchId: string,
  guestId: string
): Promise<string | null> {
  const result = await pool.query(
    `SELECT
       CASE
         WHEN guest_one_id = $2 THEN guest_two_id
         ELSE guest_one_id
       END AS partner_guest_id
     FROM matchmaking_matches
     WHERE id = $1
       AND status = 'active'
       AND (
         guest_one_id = $2
         OR guest_two_id = $2
       )
     LIMIT 1`,
    [matchId, guestId]
  );

  if (result.rows.length === 0) {
    return null;
  }

  return result.rows[0].partner_guest_id as string;
}

export const initializeSocketServer = (
  httpServer: HttpServer
): GuestSocketServer => {
  io = new Server<
    ClientToServerEvents,
    ServerToClientEvents,
    Record<string, never>,
    GuestSocketData
  >(httpServer, {
    // Large enough for SDP (max 100 KB) but blocks oversized payloads.
    maxHttpBufferSize: 256 * 1024,
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
  });

  // Authenticate every incoming socket connection.
  io.use(async (socket, next) => {
    try {
      const sessionToken = socket.handshake.auth?.token;

      if (
        typeof sessionToken !== 'string' ||
        !/^[A-Za-z0-9_-]{43}$/.test(sessionToken)
      ) {
        return next(new Error('Authentication required.'));
      }

      const tokenHash = createHash('sha256')
        .update(sessionToken)
        .digest('hex');

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
        return next(
          new Error('Invalid or expired guest session.')
        );
      }

      socket.data.guestId = result.rows[0].guest_id as string;

      next();
    } catch (error) {
      console.error('Socket authentication error:', error);
      next(new Error('Unable to authenticate connection.'));
    }
  });

  io.on('connection', (socket: GuestSocket) => {
    const guestId = socket.data.guestId;

    // Each guest has a private room for server notifications.
    void socket.join(`guest:${guestId}`);

    console.log(`[Socket] Guest connected: ${guestId}`);

    const isChatLimited = createSocketRateLimiter(20, 10_000);
    const isSignalLimited = createSocketRateLimiter(200, 10_000);

    socket.use(([event], next) => {
      const limited = event.startsWith('webrtc_')
        ? isSignalLimited()
        : isChatLimited();

      if (limited) {
        socket.emit('message_error', {
          message: 'RATE_LIMITED',
        });
        return;
      }

      next();
    });

    // --------------------------------------------------
    // TEXT CHAT: SEND MESSAGE
    // --------------------------------------------------

    socket.on('send_message', async (payload) => {
      try {
        if (
          !payload ||
          !isValidMatchId(payload.matchId) ||
          typeof payload.message !== 'string'
        ) {
          socket.emit('message_error', {
            message: 'Invalid message request.',
          });
          return;
        }

        const savedMessage = await saveMessage(
          payload.matchId,
          guestId,
          payload.message
        );

        const messageData = {
          id: savedMessage.id,
          matchId: savedMessage.matchId,
          senderGuestId: savedMessage.senderGuestId,
          message: savedMessage.message,
          createdAt: savedMessage.createdAt,
        };

        emitToGuest(guestId, 'new_message', messageData);

        emitToGuest(
          savedMessage.partnerGuestId,
          'new_message',
          messageData
        );

        console.log(
          `[Chat] Message saved in match ${savedMessage.matchId}`
        );
      } catch (error) {
        console.error('[Chat] Message sending failed:', error);

        socket.emit('message_error', {
          message: toClientError(error, 'MESSAGE_SEND_FAILED'),
        });
      }
    });

    // --------------------------------------------------
    // TEXT CHAT: CHAT HISTORY
    // --------------------------------------------------

    socket.on('get_chat_history', async (payload) => {
      try {
        if (
          !payload ||
          !isValidMatchId(payload.matchId)
        ) {
          socket.emit('message_error', {
            message: 'Invalid chat history request.',
          });
          return;
        }

        const requestedLimit =
          Number.isInteger(payload.limit)
            ? (payload.limit as number)
            : 50;

        const messages = await getChatHistory(
          payload.matchId,
          guestId,
          requestedLimit
        );

        socket.emit('chat_history', {
          matchId: payload.matchId,
          messages,
        });

        console.log(
          `[Chat] History sent for match ${payload.matchId}`
        );
      } catch (error) {
        console.error('[Chat] History retrieval failed:', error);

        socket.emit('message_error', {
          message: toClientError(error, 'CHAT_HISTORY_FAILED'),
        });
      }
    });

    // --------------------------------------------------
    // END MATCH
    // --------------------------------------------------

    socket.on('end_match', async (payload) => {
      try {
        if (
          !payload ||
          !isValidMatchId(payload.matchId)
        ) {
          socket.emit('message_error', {
            message: 'Invalid end match request.',
          });
          return;
        }

        const result = await pool.query(
          `UPDATE matchmaking_matches
           SET
             status = 'ended',
             ended_at = NOW()
           WHERE id = $1
             AND status = 'active'
             AND (
               guest_one_id = $2
               OR guest_two_id = $2
             )
           RETURNING
             CASE
               WHEN guest_one_id = $2 THEN guest_two_id
               ELSE guest_one_id
             END AS partner_guest_id`,
          [payload.matchId, guestId]
        );

        if (result.rows.length === 0) {
          socket.emit('message_error', {
            message:
              'Match is already ended or you are not authorized.',
          });
          return;
        }

        const partnerGuestId =
          result.rows[0].partner_guest_id as string;

        const endedData = {
          matchId: payload.matchId,
          endedByGuestId: guestId,
        };

        emitToGuest(guestId, 'match_ended', endedData);

        emitToGuest(
          partnerGuestId,
          'match_ended',
          endedData
        );

        console.log(`[Chat] Match ended: ${payload.matchId}`);
      } catch (error) {
        console.error('[Chat] Ending match failed:', error);

        socket.emit('message_error', {
          message: 'Unable to end the conversation.',
        });
      }
    });

    // --------------------------------------------------
    // WEBRTC: SEND OFFER
    // --------------------------------------------------

    socket.on('webrtc_offer', async (payload) => {
      try {
        if (
          !payload ||
          !isValidMatchId(payload.matchId) ||
          !isValidDescription(payload.description, 'offer')
        ) {
          socket.emit('webrtc_signal_error', {
            message: 'Invalid WebRTC offer.',
          });
          return;
        }

        const partnerGuestId = await getActiveMatchPartner(
          payload.matchId,
          guestId
        );

        if (!partnerGuestId) {
          socket.emit('webrtc_signal_error', {
            message: 'Active match not found or not authorized.',
          });
          return;
        }

        io!.to(`guest:${partnerGuestId}`).emit('webrtc_offer', {
          matchId: payload.matchId,
          fromGuestId: guestId,
          description: payload.description,
        });

        console.log(
          `[WebRTC] Offer relayed for match ${payload.matchId}`
        );
      } catch (error) {
        console.error('[WebRTC] Offer relay failed:', error);

        socket.emit('webrtc_signal_error', {
          message: 'Unable to relay WebRTC offer.',
        });
      }
    });

    // --------------------------------------------------
    // WEBRTC: SEND ANSWER
    // --------------------------------------------------

    socket.on('webrtc_answer', async (payload) => {
      try {
        if (
          !payload ||
          !isValidMatchId(payload.matchId) ||
          !isValidDescription(payload.description, 'answer')
        ) {
          socket.emit('webrtc_signal_error', {
            message: 'Invalid WebRTC answer.',
          });
          return;
        }

        const partnerGuestId = await getActiveMatchPartner(
          payload.matchId,
          guestId
        );

        if (!partnerGuestId) {
          socket.emit('webrtc_signal_error', {
            message: 'Active match not found or not authorized.',
          });
          return;
        }

        io!.to(`guest:${partnerGuestId}`).emit('webrtc_answer', {
          matchId: payload.matchId,
          fromGuestId: guestId,
          description: payload.description,
        });

        console.log(
          `[WebRTC] Answer relayed for match ${payload.matchId}`
        );
      } catch (error) {
        console.error('[WebRTC] Answer relay failed:', error);

        socket.emit('webrtc_signal_error', {
          message: 'Unable to relay WebRTC answer.',
        });
      }
    });

    // --------------------------------------------------
    // WEBRTC: SEND ICE CANDIDATE
    // --------------------------------------------------

    socket.on('webrtc_ice_candidate', async (payload) => {
      try {
        if (
          !payload ||
          !isValidMatchId(payload.matchId) ||
          !isValidIceCandidate(payload.candidate)
        ) {
          socket.emit('webrtc_signal_error', {
            message: 'Invalid WebRTC ICE candidate.',
          });
          return;
        }

        const partnerGuestId = await getActiveMatchPartner(
          payload.matchId,
          guestId
        );

        if (!partnerGuestId) {
          socket.emit('webrtc_signal_error', {
            message: 'Active match not found or not authorized.',
          });
          return;
        }

        io!.to(`guest:${partnerGuestId}`).emit(
          'webrtc_ice_candidate',
          {
            matchId: payload.matchId,
            fromGuestId: guestId,
            candidate: payload.candidate,
          }
        );

        console.log(
          `[WebRTC] ICE candidate relayed for match ${payload.matchId}`
        );
      } catch (error) {
        console.error('[WebRTC] ICE relay failed:', error);

        socket.emit('webrtc_signal_error', {
          message: 'Unable to relay ICE candidate.',
        });
      }
    });

    // --------------------------------------------------
    // DISCONNECT
    // --------------------------------------------------

    socket.on('disconnect', (reason) => {
      console.log(
        `[Socket] Guest disconnected: ${guestId}. Reason: ${reason}`
      );
    });
  });

  console.log('[Socket] Socket.IO server initialized.');

  return io;
};

// --------------------------------------------------
// EMIT TO GUEST: EXISTING EVENTS
// --------------------------------------------------

export function emitToGuest(
  guestId: string,
  event: 'match_found',
  data: {
    matchId: string;
    partnerGuestId: string;
  }
): void;

export function emitToGuest(
  guestId: string,
  event: 'new_message',
  data: ChatMessage
): void;

export function emitToGuest(
  guestId: string,
  event: 'match_ended',
  data: {
    matchId: string;
    endedByGuestId: string;
  }
): void;

export function emitToGuest(
  guestId: string,
  event: 'match_found' | 'new_message' | 'match_ended',
  data:
    | {
        matchId: string;
        partnerGuestId: string;
      }
    | ChatMessage
    | {
        matchId: string;
        endedByGuestId: string;
      }
): void {
  if (!io) {
    console.error(
      '[Socket] Cannot emit event: server not initialized.'
    );
    return;
  }

  if (event === 'match_found') {
    io.to(`guest:${guestId}`).emit('match_found', data as {
      matchId: string;
      partnerGuestId: string;
    });
  } else if (event === 'new_message') {
    io.to(`guest:${guestId}`).emit('new_message', data as ChatMessage);
  } else {
    io.to(`guest:${guestId}`).emit('match_ended', data as {
      matchId: string;
      endedByGuestId: string;
    });
  }
}
