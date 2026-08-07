export async function up(knex) {
  const exists = await knex.schema.hasTable('post_comments');
  if (exists) return;
  await knex.schema.createTable('post_comments', (table) => {
    table.string('id', 36).primary();
    table.string('post_id', 36).notNullable().references('id').inTable('posts').onDelete('CASCADE');
    table.string('user_id', 36).notNullable().references('id').inTable('users').onDelete('CASCADE');
    table.string('content', 200).notNullable();
    table.timestamp('created_at').notNullable().defaultTo(knex.fn.now());
    table.index(['post_id', 'created_at']);
    table.index(['user_id', 'created_at']);
  });
}

export async function down(knex) {
  await knex.schema.dropTableIfExists('post_comments');
}
