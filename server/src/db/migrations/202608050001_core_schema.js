export async function up(knex) {
  await knex.schema.createTable('users', (table) => {
    table.string('id', 36).primary(); table.string('nickname', 32).notNullable().unique();
    table.string('real_name', 64).notNullable(); table.string('identity_number', 64).notNullable().unique();
    table.enu('identity_role', ['STUDENT', 'TEACHER', 'STAFF']).notNullable();
    table.string('department', 128).notNullable(); table.string('grade', 32); table.string('campus', 128).notNullable();
    table.string('phone', 32).notNullable().unique(); table.string('email', 255).notNullable().unique();
    table.enu('status', ['NORMAL', 'FROZEN', 'DELETED']).notNullable().defaultTo('NORMAL');
    table.timestamps(true, true);
  });
  await knex.schema.createTable('user_credentials', (table) => {
    table.string('user_id', 36).primary().references('id').inTable('users').onDelete('CASCADE');
    table.string('password_hash', 255).notNullable(); table.timestamps(true, true);
  });
  await knex.schema.createTable('sessions', (table) => {
    table.string('id', 36).primary(); table.string('user_id', 36).notNullable().references('id').inTable('users');
    table.timestamp('expires_at').notNullable(); table.timestamp('revoked_at'); table.timestamps(true, true);
  });
  await knex.schema.createTable('posts', (table) => {
    table.string('id', 36).primary(); table.string('owner_id', 36).notNullable().references('id').inTable('users');
    table.enu('kind', ['LOST_NOTICE', 'SEARCH_NOTICE']).notNullable(); table.string('title', 80).notNullable();
    table.text('description').notNullable(); table.string('category', 64).notNullable(); table.string('location', 255).notNullable();
    table.string('campus', 128).notNullable(); table.string('contact', 255).notNullable();
    table.enu('status', ['ACTIVE', 'RESOLVED', 'CLOSED']).notNullable().defaultTo('ACTIVE');
    table.timestamp('resolved_at'); table.timestamps(true, true); table.index(['status', 'created_at']);
  });
  await knex.schema.createTable('post_images', (table) => {
    table.string('id', 36).primary(); table.string('owner_id', 36).notNullable().references('id').inTable('users');
    table.string('object_key', 512).notNullable().unique(); table.string('public_url', 1024).notNullable();
    table.string('content_type', 64).notNullable(); table.bigInteger('size_bytes').notNullable();
    table.enu('status', ['TEMPORARY', 'ATTACHED']).notNullable().defaultTo('TEMPORARY'); table.timestamps(true, true);
    table.index(['owner_id', 'status']);
  });
  await knex.schema.createTable('post_image_links', (table) => {
    table.string('post_id', 36).notNullable().references('id').inTable('posts').onDelete('CASCADE');
    table.string('image_id', 36).notNullable().unique().references('id').inTable('post_images');
    table.integer('position').notNullable(); table.primary(['post_id', 'image_id']);
  });
  await knex.schema.createTable('claims', (table) => {
    table.string('id', 36).primary(); table.string('post_id', 36).notNullable().references('id').inTable('posts');
    table.string('applicant_id', 36).notNullable().references('id').inTable('users'); table.string('answer', 500).notNullable();
    table.enu('status', ['PENDING', 'COMPLETED']).notNullable().defaultTo('PENDING'); table.timestamp('completed_at'); table.timestamps(true, true);
    table.index(['post_id', 'status']);
  });
  await knex.schema.createTable('clues', (table) => {
    table.string('id', 36).primary(); table.string('post_id', 36).notNullable().references('id').inTable('posts');
    table.string('author_id', 36).notNullable().references('id').inTable('users'); table.string('content', 500).notNullable(); table.timestamps(true, true);
    table.index(['post_id', 'created_at']);
  });
}

export async function down(knex) {
  await knex.schema.dropTableIfExists('clues'); await knex.schema.dropTableIfExists('claims');
  await knex.schema.dropTableIfExists('post_image_links'); await knex.schema.dropTableIfExists('post_images');
  await knex.schema.dropTableIfExists('posts'); await knex.schema.dropTableIfExists('sessions');
  await knex.schema.dropTableIfExists('user_credentials'); await knex.schema.dropTableIfExists('users');
}
