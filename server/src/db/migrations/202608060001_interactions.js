export async function up(knex) {
  const hasLikes = await knex.schema.hasTable('post_likes');
  if (!hasLikes) {
    await knex.schema.createTable('post_likes', (table) => {
      table.specificType('post_id', 'CHAR(36)').notNullable();
      table.specificType('user_id', 'CHAR(36)').notNullable();
      table.timestamp('created_at').notNullable().defaultTo(knex.fn.now());
      table.primary(['post_id', 'user_id']);
      table.foreign('post_id').references('posts.id').onDelete('CASCADE');
      table.foreign('user_id').references('users.id').onDelete('CASCADE');
      table.index(['user_id']);
      table.index(['post_id']);
    });
  }
  const hasFavorites = await knex.schema.hasTable('post_favorites');
  if (!hasFavorites) {
    await knex.schema.createTable('post_favorites', (table) => {
      table.specificType('post_id', 'CHAR(36)').notNullable();
      table.specificType('user_id', 'CHAR(36)').notNullable();
      table.timestamp('created_at').notNullable().defaultTo(knex.fn.now());
      table.primary(['post_id', 'user_id']);
      table.foreign('post_id').references('posts.id').onDelete('CASCADE');
      table.foreign('user_id').references('users.id').onDelete('CASCADE');
      table.index(['user_id']);
      table.index(['post_id']);
    });
  }
}

export async function down(knex) {
  await knex.schema.dropTableIfExists('post_favorites');
  await knex.schema.dropTableIfExists('post_likes');
}
