
import pool from '../config/database.js';

interface CreateUserInput {
  displayName: string;
  bio?: string | null;
}

interface CreatedUser {
  id: string;
  displayName: string;
  bio: string | null;
}

export const createUser = async (
  input: CreateUserInput
): Promise<CreatedUser> => {
  // Get a database connection from the pool
  const client = await pool.connect();

  try {
    // Start database transaction
    await client.query('BEGIN');

    // Create user account
    const userResult = await client.query<{ id: string }>(
      `INSERT INTO users DEFAULT VALUES RETURNING id`
    );

    const userId = userResult.rows[0].id;

    // Create user profile
    await client.query(
      `INSERT INTO user_profiles (user_id, display_name, bio)
       VALUES ($1, $2, $3)`,
      [userId, input.displayName, input.bio ?? null]
    );

    // Commit transaction
    await client.query('COMMIT');

    return {
      id: userId,
      displayName: input.displayName,
      bio: input.bio ?? null,
    };
  } catch (error) {
    // Roll back if any database operation fails
    await client.query('ROLLBACK');

    throw error;
  } finally {
    // Release connection back to the pool
    client.release();
  }
};

export const getUserById = async (
  userId: string
): Promise<{
  id: string;
  displayName: string;
  bio: string | null;
  isActive: boolean;
} | null> => {
  const result = await pool.query(
    `SELECT
        users.id,
        users.is_active,
        user_profiles.display_name,
        user_profiles.bio
     FROM users
     INNER JOIN user_profiles
        ON users.id = user_profiles.user_id
     WHERE users.id = $1`,
    [userId]
  );

  // User not found
  if (result.rows.length === 0) {
    return null;
  }

  const user = result.rows[0];

  return {
    id: user.id,
    displayName: user.display_name,
    bio: user.bio,
    isActive: user.is_active,
  };
};

interface UpdateUserInput {
  displayName: string;
  bio: string | null;
}

export const updateUser = async (
  userId: string,
  input: UpdateUserInput
): Promise<{
  id: string;
  displayName: string;
  bio: string | null;
  isActive: boolean;
} | null> => {
  const result = await pool.query(
    `UPDATE user_profiles
     SET
       display_name = $2,
       bio = $3,
       updated_at = NOW()
     WHERE user_id = $1
     RETURNING
       user_id,
       display_name,
       bio,
       (
         SELECT is_active
         FROM users
         WHERE id = user_profiles.user_id
       ) AS is_active`,
    [userId, input.displayName, input.bio]
  );

  // No profile was found for this user ID
  if (result.rows.length === 0) {
    return null;
  }

  const user = result.rows[0];

  return {
    id: user.user_id,
    displayName: user.display_name,
    bio: user.bio,
    isActive: user.is_active,
  };
};

export const deactivateUser = async (
  userId: string
): Promise<boolean> => {
  const result = await pool.query(
    `UPDATE users
     SET
       is_active = FALSE,
       updated_at = NOW()
     WHERE id = $1
       AND is_active = TRUE
     RETURNING id`,
    [userId]
  );

  // If one row was updated, return true
  return result.rowCount === 1;
};