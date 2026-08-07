export async function up(knex) {
  const hasAdminColumn = await knex.schema.hasColumn('users', 'is_admin');
  if (!hasAdminColumn) {
    await knex.schema.alterTable('users', (table) => {
      table.boolean('is_admin').notNullable().defaultTo(false);
    });
  }
  await knex.raw("ALTER TABLE posts MODIFY COLUMN status ENUM('ACTIVE','RESOLVED','CLOSED','DELETED') NOT NULL DEFAULT 'ACTIVE'");
}

export async function down(knex) {
  await knex('posts').where({ status: 'DELETED' }).update({ status: 'CLOSED' });
  await knex.raw("ALTER TABLE posts MODIFY COLUMN status ENUM('ACTIVE','RESOLVED','CLOSED') NOT NULL DEFAULT 'ACTIVE'");
  const hasAdminColumn = await knex.schema.hasColumn('users', 'is_admin');
  if (hasAdminColumn) {
    await knex.schema.alterTable('users', (table) => table.dropColumn('is_admin'));
  }
}
