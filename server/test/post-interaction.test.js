import test from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import request from 'supertest';
import { PostService } from '../src/posts/post.service.js';
import { createPostRouter } from '../src/posts/post.routes.js';
import { requireAdmin } from '../src/auth/require-admin.js';

class FakePostRepository {
  constructor() {
    this.likes = new Set();
    this.favorites = new Set();
  }

  async setInteraction(table, postId, userId, enabled) {
    const target = table === 'post_likes' ? this.likes : this.favorites;
    const key = `${postId}:${userId}`;
    if (enabled) target.add(key); else target.delete(key);
    return {
      likeCount: this.likes.size,
      isLiked: this.likes.has(key),
      favoriteCount: this.favorites.size,
      isFavorite: this.favorites.has(key)
    };
  }

  async list() {
    return { rows: [{ id: 'post-1', owner_id: 'owner-1', owner_nickname: 'Owner', kind: 'LOST_NOTICE',
      title: 'Lost', category: 'Other', location: 'Hall', campus: 'Main', status: 'ACTIVE', description: 'desc',
      created_at: '2026-08-06T00:00:00.000Z' }], total: 1 };
  }

  async listInteractions() {
    return new Map([['post-1', { likeCount: 2, isLiked: true, favoriteCount: 1, isFavorite: false }]]);
  }

  async findDetail() {
    return { id: 'post-1', owner_id: 'owner-1', owner_nickname: 'Owner', owner_department: 'CS', kind: 'LOST_NOTICE',
      title: 'Lost', category: 'Other', location: 'Hall', campus: 'Main', status: 'ACTIVE', description: 'desc',
      contact: 'contact', created_at: '2026-08-06T00:00:00.000Z', images: [] };
  }

  async getInteractions() {
    return { likeCount: 2, isLiked: true, favoriteCount: 1, isFavorite: false };
  }

  async updateStatus(_postId, status) {
    return { ...await this.findDetail(), status };
  }
}

test('post list and detail expose interaction state', async () => {
  const service = new PostService(new FakePostRepository());
  const list = await service.list({}, 'user-1');
  assert.equal(list.items[0].likeCount, 2);
  assert.equal(list.items[0].isLiked, true);
  const detail = await service.detail('post-1', 'user-1');
  assert.equal(detail.favoriteCount, 1);
  assert.equal(detail.isFavorite, false);
});

test('like and favorite writes are idempotent', async () => {
  const repository = new FakePostRepository();
  const service = new PostService(repository);
  await service.setLike('post-1', 'user-1', true);
  const secondLike = await service.setLike('post-1', 'user-1', true);
  assert.equal(secondLike.likeCount, 1);
  await service.setLike('post-1', 'user-1', false);
  const favorite = await service.setFavorite('post-1', 'user-1', true);
  assert.equal(favorite.favoriteCount, 1);
  const secondFavorite = await service.setFavorite('post-1', 'user-1', false);
  assert.equal(secondFavorite.favoriteCount, 0);
});

test('interaction PUT accepts enabled=false for native clients', async () => {
  let enabled;
  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => { req.auth = { userId: 'user-1' }; next(); });
  app.use('/', createPostRouter({
    setLike: async (_postId, _userId, value) => { enabled = value; return { postId: 'post-1', likeCount: 0, isLiked: value, favoriteCount: 0, isFavorite: false }; },
    setFavorite: async () => ({ postId: 'post-1', likeCount: 0, isLiked: false, favoriteCount: 0, isFavorite: false }),
    list: async () => ({ items: [], total: 0 }),
    create: async () => ({}),
    detail: async () => ({})
  }));
  await request(app).put('/post-1/like').send({ enabled: false }).expect(200);
  assert.equal(enabled, false);
});

test('admin can soft-delete and restore a post without removing its data', async () => {
  const service = new PostService(new FakePostRepository());
  const deleted = await service.setAdminStatus('post-1', 'DELETED');
  assert.equal(deleted.status, 'DELETED');
  assert.equal(deleted.title, 'Lost');
  const restored = await service.setAdminStatus('post-1', 'ACTIVE');
  assert.equal(restored.status, 'ACTIVE');
  assert.equal(restored.title, 'Lost');
});

test('non-admin requests are rejected by the admin guard', () => {
  let received;
  requireAdmin({ auth: { isAdmin: false } }, {}, (error) => { received = error; });
  assert.equal(received.code, 'AUTH_FORBIDDEN');
  assert.equal(received.status, 403);
});
