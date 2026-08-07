import { ApiError } from '../common/errors.js';

function clean(value) { return typeof value === 'string' ? value.trim() : ''; }

export class CommentService {
  constructor(repository) { this.repository = repository; }

  async list(postId) {
    await this.requireAvailablePost(postId);
    return (await this.repository.list(postId)).map((row) => this.toComment(row));
  }

  async create(userId, postId, value) {
    await this.requireAvailablePost(postId);
    const content = clean(value);
    if (content.length < 1 || content.length > 200) {
      throw new ApiError('COMMENT_INVALID', '评论须为 1 至 200 个字符', 400);
    }
    return this.toComment(await this.repository.create(postId, userId, content));
  }

  async requireAvailablePost(postId) {
    const post = await this.repository.findPost(postId);
    if (!post) throw new ApiError('POST_NOT_FOUND', '帖子不存在', 404);
    if (post.status === 'DELETED') throw new ApiError('POST_NOT_AVAILABLE', '该帖子不可评论', 409);
    return post;
  }

  toComment(row) {
    return {
      id: row.id,
      postId: row.post_id,
      userId: row.user_id,
      userName: row.user_nickname,
      content: row.content,
      createdAt: row.created_at
    };
  }
}
