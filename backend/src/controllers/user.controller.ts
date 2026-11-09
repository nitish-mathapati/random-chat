
import type { Request, Response } from 'express';

import { createUser, getUserById, updateUser, deactivateUser } from '../services/user.service.js';

export const registerUser = async (
  request: Request,
  response: Response
): Promise<void> => {
  try {
    // Read incoming request data
    const { displayName, bio } = request.body ?? {};

    // Validate display name
    if (
      typeof displayName !== 'string' ||
      displayName.trim().length < 3 ||
      displayName.trim().length > 50
    ) {
      response.status(400).json({
        status: 'error',
        message: 'Display name must be between 3 and 50 characters.',
      });
      return;
    }

    // Validate optional bio
    if (bio !== undefined && bio !== null && typeof bio !== 'string') {
      response.status(400).json({
        status: 'error',
        message: 'Bio must be a string.',
      });
      return;
    }

    const trimmedBio = typeof bio === 'string' ? bio.trim() : null;

    if (trimmedBio !== null && trimmedBio.length > 250) {
      response.status(400).json({
        status: 'error',
        message: 'Bio cannot exceed 250 characters.',
      });
      return;
    }

    // Prepare validated input
    const userData = {
      displayName: displayName.trim(),
      bio: trimmedBio || null,
    };

    // Create user using the service
    const newUser = await createUser(userData);

    // Return successful response
    response.status(201).json({
      status: 'success',
      message: 'User registered successfully.',
      data: newUser,
    });
  } catch (error) {
    console.error('User registration error:', error);

    response.status(500).json({
      status: 'error',
      message: 'Unable to register user. Please try again later.',
    });
  }
};

export const getUserProfile = async (
  request: Request,
  response: Response
): Promise<void> => {
  try {
    const userId = request.params.id;

    if (typeof userId !== 'string') {
      response.status(400).json({
        status: 'error',
        message: 'Invalid user ID format.',
      });
      return;
    }

    // Validate UUID format
    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

    if (!uuidRegex.test(userId)) {
      response.status(400).json({
        status: 'error',
        message: 'Invalid user ID format.',
      });
      return;
    }

    // Retrieve user from database
    const user = await getUserById(userId);

    // Check whether user exists
    if (!user) {
      response.status(404).json({
        status: 'error',
        message: 'User not found.',
      });
      return;
    }

    response.status(200).json({
      status: 'success',
      data: user,
    });
  } catch (error) {
    console.error('Get user profile error:', error);

    response.status(500).json({
      status: 'error',
      message: 'Unable to retrieve user profile.',
    });
  }
};

export const updateUserProfile = async (
  request: Request,
  response: Response
): Promise<void> => {
  try {
    const userId = request.params.id;

    // Validate UUID parameter type
    if (typeof userId !== 'string') {
      response.status(400).json({
        status: 'error',
        message: 'Invalid user ID format.',
      });
      return;
    }

    // Validate UUID format
    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

    if (!uuidRegex.test(userId)) {
      response.status(400).json({
        status: 'error',
        message: 'Invalid user ID format.',
      });
      return;
    }

    // Read request body
    const { displayName, bio } = request.body ?? {};

    // Validate display name
    if (
      typeof displayName !== 'string' ||
      displayName.trim().length < 3 ||
      displayName.trim().length > 50
    ) {
      response.status(400).json({
        status: 'error',
        message: 'Display name must be between 3 and 50 characters.',
      });
      return;
    }

    // Validate bio
    if (bio !== null && typeof bio !== 'string') {
      response.status(400).json({
        status: 'error',
        message: 'Bio must be a string or null.',
      });
      return;
    }

    const trimmedBio = typeof bio === 'string' ? bio.trim() : null;

    if (trimmedBio !== null && trimmedBio.length > 250) {
      response.status(400).json({
        status: 'error',
        message: 'Bio cannot exceed 250 characters.',
      });
      return;
    }

    // Prepare validated input
    const userData = {
      displayName: displayName.trim(),
      bio: trimmedBio || null,
    };

    // Update user profile
    const updatedUser = await updateUser(userId, userData);

    // Check whether user exists
    if (!updatedUser) {
      response.status(404).json({
        status: 'error',
        message: 'User not found.',
      });
      return;
    }

    response.status(200).json({
      status: 'success',
      message: 'User profile updated successfully.',
      data: updatedUser,
    });
  } catch (error) {
    console.error('Update user profile error:', error);

    response.status(500).json({
      status: 'error',
      message: 'Unable to update user profile.',
    });
  }
};

export const deactivateUserProfile = async (
  request: Request,
  response: Response
): Promise<void> => {
  try {
    const userId = request.params.id;

    // Validate UUID parameter type
    if (typeof userId !== 'string') {
      response.status(400).json({
        status: 'error',
        message: 'Invalid user ID format.',
      });
      return;
    }

    // Validate UUID format
    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

    if (!uuidRegex.test(userId)) {
      response.status(400).json({
        status: 'error',
        message: 'Invalid user ID format.',
      });
      return;
    }

    // Deactivate user account
    const isDeactivated = await deactivateUser(userId);

    // Check whether the user exists and is active
    if (!isDeactivated) {
      response.status(404).json({
        status: 'error',
        message: 'User not found or already inactive.',
      });
      return;
    }

    response.status(200).json({
      status: 'success',
      message: 'User account deactivated successfully.',
      data: {
        id: userId,
        isActive: false,
      },
    });
  } catch (error) {
    console.error('Deactivate user error:', error);

    response.status(500).json({
      status: 'error',
      message: 'Unable to deactivate user account.',
    });
  }
};