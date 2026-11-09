import { Router } from 'express';

import {
  registerUser,
  getUserProfile,
  updateUserProfile,
  deactivateUserProfile,
} from '../controllers/user.controller.js';

const router = Router();

// POST /api/users - Register a new user
router.post('/', registerUser);

// GET /api/users/:id - Retrieve user profile
router.get('/:id', getUserProfile);

// PUT /api/users/:id - Update user profile
router.put('/:id', updateUserProfile);

// DELETE /api/users/:id - Deactivate user account
router.delete('/:id', deactivateUserProfile);

export default router;