import knex from 'knex';

function withUtf8mb4(connectionString) {
  if (/[?&]charset=/i.test(connectionString)) return connectionString;
  return connectionString + (connectionString.includes('?') ? '&' : '?') + 'charset=utf8mb4';
}

export function createDatabase(connectionString) {
  return knex({
    client: 'mysql2',
    connection: withUtf8mb4(connectionString),
    pool: { min: 0, max: 10 }
  });
}

export default {
  client: 'mysql2',
  connection: process.env.DATABASE_URL,
  migrations: {
    directory: new URL('./migrations', import.meta.url).pathname
  }
};
