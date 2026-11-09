
import { Pool } from 'pg';

// PostgreSQL connection configuration
const pool = new Pool({
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5432),
  database: process.env.DB_NAME ?? 'userchat',
  user: process.env.DB_USER ?? 'postgres',
  password: process.env.DB_PASSWORD,
});

// Log unexpected errors from idle database connections
pool.on('error', (error: Error) => {
  console.error('Unexpected PostgreSQL connection error:', error);
});

export default pool;
