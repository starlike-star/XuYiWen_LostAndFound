import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { createDatabase } from '../src/db/knex.js';
import { NotificationService } from '../src/notifications/notification.service.js';
import { RemoteStorageService } from '../src/files/remote-storage.service.js';

test('health liveness endpoint responds without querying MySQL', async () => {
  const db = {
    raw: async () => {
      throw new Error('liveness must not query MySQL');
    }
  };

  const response = await request(createApp({ db }))
    .get('/health/live')
    .expect(200);

  assert.equal(response.body.code, 'OK');
  assert.equal(response.body.data.status, 'live');
});

test('malformed JSON requests return a client error', async () => {
  const response = await request(createApp({ db: { raw: async () => ({}) } }))
    .post('/api/v1/auth/login/password')
    .set('Content-Type', 'application/json')
    .send("{'account':'13800000001','password':'Campus123'}")
    .expect(400);

  assert.equal(response.body.code, 'INVALID_JSON');
});

test('database connections use utf8mb4 for user content', async () => {
  const db = createDatabase('mysql://user:password@127.0.0.1:3308/lostfound');
  assert.equal(db.client.config.connection.charset, 'utf8mb4');
  await db.destroy();
});

test('notification service returns stable message cards', async () => {
  const service = new NotificationService({
    list: async () => [{
      sourceId: 'claim-1', type: 'CLAIM_RECEIVED', content: '请描述水杯底部特征',
      postId: 'post-1', createdAt: '2026-08-06T00:00:00.000Z'
    }]
  });

  const result = await service.list('student-1');
  assert.equal(result.items.length, 1);
  assert.equal(result.items[0].id, 'claim-received-claim-1');
  assert.equal(result.items[0].title, '收到认领申请');
  assert.equal(result.items[0].read, false);
});

test('notification service persists and returns read state', async () => {
  let readIds = [];
  const service = new NotificationService({
    list: async () => [{
      sourceId: 'claim-1', type: 'CLAIM_RECEIVED', content: '请描述水杯底部特征',
      postId: 'post-1', createdAt: '2026-08-06T00:00:00.000Z'
    }],
    listReadIds: async () => readIds,
    markRead: async (_userId, ids) => { readIds = ids; }
  });
  await service.markRead('student-1', ['claim-received-claim-1']);
  const result = await service.list('student-1');
  assert.equal(result.items[0].read, true);
});

test('remote storage errors preserve the upstream status for diagnosis', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => new Response('unauthorized', { status: 401 });
  try {
    const storage = new RemoteStorageService('http://192.168.137.10:8081', 'x'.repeat(32), 'http://localhost:3000');
    await assert.rejects(() => storage.save(Buffer.from('bad'), 'image/png'), (error) => {
      assert.equal(error.code, 'STORAGE_UPLOAD_FAILED');
      assert.equal(error.status, 502);
      assert.match(error.message, /HTTP 401/);
      return true;
    });
  } finally {
    globalThis.fetch = originalFetch;
  }
});
