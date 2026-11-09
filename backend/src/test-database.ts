
import 'dotenv/config';

import pool from './config/database.js';

const testDatabaseConnection = async (): Promise<void> => {
  try {
    console.log('Connecting to PostgreSQL...');

    const result = await pool.query(
      'SELECT current_database(), current_user, version()'
    );

    console.log('\nDatabase connection successful!');
    console.log('Database:', result.rows[0].current_database);
    console.log('User:', result.rows[0].current_user);
    console.log('Version:', result.rows[0].version);
  } catch (error) {
    console.error('\nDatabase connection failed:', error);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
};

testDatabaseConnection();
