
-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create user profiles table
CREATE TABLE user_profiles (
    user_id UUID PRIMARY KEY,

    display_name VARCHAR(50) NOT NULL,

    bio VARCHAR(250),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_user_profile
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);
