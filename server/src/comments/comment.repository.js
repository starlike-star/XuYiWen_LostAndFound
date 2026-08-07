import { randomUUID } from 'node:crypto';

export class CommentRepository {
  constructor(db) { this.db = db; }

  findPost(id) {
    return this.db('posts').where({ id }).first('id', 'status');
  }

  async create(postId, userId, content) {
    const row = { id: randomUUID(), post_id: postId, user_id: userId, content };
    await this.db('post_comments').insert(row);
    return this.findById(row.id);
  }

  findById(id) {
    return this.db('post_comments as comment')
      .join('users as u', 'u.id', 'comment.user_id')
      .select('comment.*', 'u.nickname as user_nickname')
      .where('comment.id', id).first();
  }

  list(postId) {
    return this.db('post_comments as comment')
      .join('users as u', 'u.id', 'comment.user_id')
      .select('comment.*', 'u.nickname as user_nickname')
      .where('comment.post_id', postId)
      .orderBy('comment.created_at', 'asc');
  }
}
