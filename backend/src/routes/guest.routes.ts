
import { Router } from 'express';

import {
  createGuestSessionController,
  restoreGuestSessionController,
  logoutGuestSessionController,
} from '../controllers/guest.controller.js';

const router = Router();

router.post('/session', createGuestSessionController);

router.post('/restore', restoreGuestSessionController);

router.post('/logout', logoutGuestSessionController);

export default router;
