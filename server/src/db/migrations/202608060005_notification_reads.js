export async function up(knex) {
  const exists = await knex.schema.hasTable('notification_reads');
  if (exists) return;
  await knex.schema.createTable('notification_reads', (table) => {
    table.string('user_id', 36).notNullable().references('id').inTable('users').onDelete('CASCADE');
    table.string('notification_id', 160).notNullable();
    table.timestamp('read_at').notNullable().defaultTo(knex.fn.now());
    table.primary(['user_id', 'notification_id']);
    table.index(['user_id', 'read_at']);
  });
}

export async function down(knex) {
  await knex.schema.dropTableIfExists('notification_reads');
}
