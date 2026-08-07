import test from 'node:test';
import assert from 'node:assert/strict';
import { CommentService } from '../src/comments/comment.service.js';

class FakeCommentRepository {
  constructor() {
    this.comments = [];
  }

  async findPost(id) {
    return id === 'post-1' ? { id, status: 'ACTIVE' } : undefined;
  }

  async create(postId, userId, content) {
    const row = { id: `comment-${this.comments.length + 1}`, post_id: postId, user_id: userId,
      content, user_nickname: '测试用户', created_at: '2026-08-06T00:00:00.000Z' };
    this.comments.push(row);
    return row;
  }

  async list(postId) {
    return this.comments.filter((comment) => comment.post_id === postId);
  }
}

test('comments can be created and listed with author information', async () => {
  const service = new CommentService(new FakeCommentRepository());
  const created = await service.create('user-1', 'post-1', '  这是一条评论  ');
  assert.equal(created.content, '这是一条评论');
  assert.equal(created.userName, '测试用户');
  const comments = await service.list('post-1');
  assert.equal(comments.length, 1);
  assert.equal(comments[0].postId, 'post-1');
});

test('comment validation rejects empty and oversized content', async () => {
  const service = new CommentService(new FakeCommentRepository());
  await assert.rejects(() => service.create('user-1', 'post-1', '  '), (error) => {
    assert.equal(error.code, 'COMMENT_INVALID');
    assert.equal(error.status, 400);
    return true;
  });
  await assert.rejects(() => service.create('user-1', 'post-1', 'x'.repeat(201)), (error) => {
    assert.equal(error.code, 'COMMENT_INVALID');
    return true;
  });
});

test('deleted or missing posts cannot receive comments', async () => {
  const service = new CommentService({
    findPost: async (id) => id === 'deleted' ? { id, status: 'DELETED' } : undefined
  });
  await assert.rejects(() => service.list('missing'), (error) => {
    assert.equal(error.code, 'POST_NOT_FOUND');
    return true;
  });
  await assert.rejects(() => service.create('user-1', 'deleted', 'comment'), (error) => {
    assert.equal(error.code, 'POST_NOT_AVAILABLE');
    return true;
  });
});
