import { Router } from 'express';

import {
  joinMatchmaking,
  cancelMatchmaking,
  getMatchmakingStatusController,
} from '../controllers/matchmaking.controller.js';

import guestAuthMiddleware from '../middleware/guest-auth.middleware.js';

const router = Router();

router.post('/join', guestAuthMiddleware, joinMatchmaking);

router.post('/cancel', guestAuthMiddleware, cancelMatchmaking);

router.get('/status', guestAuthMiddleware, getMatchmakingStatusController);

export default router;