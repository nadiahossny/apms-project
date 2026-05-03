import { Pool } from 'pg';

const connectionString =
  process.env.DATABASE_URL ??
  'postgresql://postgres:peralta9@localhost:5432/pharma_db';

export const pool = new Pool({ connectionString });

// A helper for easy querying
export const query = (text: string, params?: any[]) => pool.query(text, params);
