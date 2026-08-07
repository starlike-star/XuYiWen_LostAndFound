# Node.js Core Backend, MySQL, and Image Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the phase-one Linux-deployable flow: password login, image upload, post publishing/list/detail, claim or clue submission, and owner-confirmed return.

**Architecture:** An Express 5 application on Node.js 22 exposes versioned HTTP routes. Route modules call services, services enforce ownership and transactions, Repository modules encapsulate Knex/MySQL, and StorageService isolates local files from a future OBS implementation. The ArkTS client uses API repositories rather than direct database or mock-content access for the phase-one flow.

**Tech Stack:** Node.js 22, Express 5, JavaScript, Knex, mysql2, bcrypt, jsonwebtoken, Multer, Node test runner, supertest, MySQL 8, Docker Compose, Nginx, HarmonyOS ArkTS/API 24.

## Global Constraints

- First phase supports password login only; do not implement phone/email verification codes, refresh tokens, administrator APIs, notifications, favorites, likes, comments, or complex claim review.
- The client must never connect to MySQL directly.
- Image URLs are derived from storage object keys; never persist a client path or raw upload filename.
- Store usable secrets only in environment variables or container secrets; never create a committed usable `.env`.
- `database/02_seed_dev.sql` is development-only and is never a production deployment step.
- Docker images pin Node.js 22 even if the developer workstation has another Node release.
- Do not delete user data, database tables, Docker volumes, existing Mock code, or unrelated files.
- Do not generate a HAP unless the user specifically requests it.

---

### Task 1: Node service foundation, schema contract, and deployment configuration

**Files:**
- Create: `server/package.json`
- Create: `server/.gitignore`
- Create: `server/src/app.js`
- Create: `server/src/server.js`
- Create: `server/src/config/env.js`
- Create: `server/src/db/knex.js`
- Create: `server/src/db/migrations/202608050001_core_schema.js`
- Create: `server/test/schema.test.js`
- Create: `database/01_schema.sql`
- Create: `database/02_seed_dev.sql`
- Create: `server/Dockerfile`
- Create: `deploy/compose.yaml`
- Create: `deploy/nginx.conf`
- Create: `deploy/.env.example`

**Interfaces:**
- Produces tables `users`, `user_credentials`, `sessions`, `posts`, `post_images`, `claims`, and `clues`.
- Produces `createApp({ db, storage, jwtSecret })` and `GET /health/live`, `GET /health/ready`.
- All successful and failed API responses use `{ code, message, data, requestId }`.

- [ ] **Step 1: Write failing schema and health tests**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { createApp } from '../src/app.js';

test('health endpoints expose liveness and readiness', async () => {
  const response = await request(createApp({ db: { raw: async () => [] } }))
    .get('/health/live').expect(200);
  assert.equal(response.body.code, 'OK');
});
```

- [ ] **Step 2: Run the test to verify RED**

Run: `npm.cmd --prefix server test -- schema.test.js`  
Expected: FAIL because `package.json` and `createApp` do not exist.

- [ ] **Step 3: Implement schema, migration command, and deployment skeleton**

Create a Knex migration using InnoDB, utf8mb4, UTC timestamps, UUID string IDs, explicit foreign keys, unique phone/email/nickname/identity-number constraints, and post-image ownership/status fields. Add npm scripts:

```json
{
  "scripts": {
    "test": "node --test",
    "start": "node src/server.js",
    "migrate": "knex --knexfile src/db/knex.js migrate:latest"
  }
}
```

Use `GET /health/live` with no database query and `GET /health/ready` with `SELECT 1`. Compose contains `mysql`, `api`, and `nginx`; only Nginx maps host port 8080 and the upload directory is a named volume.

- [ ] **Step 4: Run focused tests and configuration validation**

Run:

```powershell
npm.cmd --prefix server test -- schema.test.js
docker compose -f deploy/compose.yaml --env-file deploy/.env.example config
```

Expected: health test passes and Compose resolves all three services without revealing a usable secret.

### Task 2: Authentication middleware and password login

**Files:**
- Create: `server/src/common/api-response.js`
- Create: `server/src/common/errors.js`
- Create: `server/src/auth/auth.repository.js`
- Create: `server/src/auth/auth.service.js`
- Create: `server/src/auth/auth.routes.js`
- Create: `server/src/auth/require-auth.js`
- Create: `server/test/auth.test.js`
- Modify: `server/src/app.js`

**Interfaces:**
- `POST /api/v1/auth/login/password` consumes `{ account, password }`.
- It returns `{ accessToken, expiresAt, user }`, where user contains no password data.
- `requireAuth` sets `req.auth = { userId, role }` or returns a uniform 401 envelope.

- [ ] **Step 1: Write failing login tests**

```js
test('normalizes email and returns an access token', async () => {
  const response = await request(app).post('/api/v1/auth/login/password')
    .send({ account: ' LIN@CAMPUS.EDU.CN ', password: 'Campus123' }).expect(200);
  assert.match(response.body.data.accessToken, /^[\w-]+\.[\w-]+\.[\w-]+$/);
  assert.equal(response.body.data.user.email, 'lin@campus.edu.cn');
});

test('rejects wrong passwords, frozen accounts, and missing bearer tokens', async () => {
  await request(app).post('/api/v1/auth/login/password')
    .send({ account: '13800000001', password: 'wrong' }).expect(401);
  await request(app).get('/api/v1/posts').expect(401);
});
```

- [ ] **Step 2: Run the authentication tests to verify RED**

Run: `npm.cmd --prefix server test -- auth.test.js`  
Expected: FAIL because auth route and middleware do not exist.

- [ ] **Step 3: Implement the minimum secure boundary**

Repository resolves a trimmed phone or lower-cased email and obtains status and bcrypt hash. Service rejects non-`NORMAL` users, calls `bcrypt.compare`, then signs a 15-minute JWT containing only `sub` and `role`. Middleware accepts only a valid Bearer token. Route errors return `AUTH_INVALID_CREDENTIALS`, `AUTH_FORBIDDEN`, or `AUTH_UNAUTHORIZED` without exposing a hash or account existence details.

- [ ] **Step 4: Run authentication tests to verify GREEN**

Run: `npm.cmd --prefix server test -- auth.test.js`  
Expected: PASS for phone/email login, invalid password, status rejection, and protected-route authentication.

### Task 3: Local image storage and temporary-upload ownership

**Files:**
- Create: `server/src/files/storage.service.js`
- Create: `server/src/files/local-storage.service.js`
- Create: `server/src/files/file.repository.js`
- Create: `server/src/files/file.service.js`
- Create: `server/src/files/file.routes.js`
- Create: `server/test/files.test.js`
- Modify: `server/src/app.js`

**Interfaces:**
- `StorageService.save(buffer, contentType) -> { objectKey, publicUrl, sizeBytes }`.
- `POST /api/v1/files/images` accepts multipart field `file` and returns a temporary image record.
- `DELETE /api/v1/files/images/:id` only deletes an unassociated image owned by the authenticated user.

- [ ] **Step 1: Write failing upload and ownership tests**

```js
test('accepts a PNG as a temporary image', async () => {
  const response = await request(app).post('/api/v1/files/images')
    .set('Authorization', bearerA)
    .attach('file', Buffer.from([0x89, 0x50, 0x4e, 0x47]), 'lost.png').expect(201);
  assert.equal(response.body.data.status, 'TEMPORARY');
  assert.match(response.body.data.publicUrl, /^\/uploads\//);
});

test('rejects invalid images and foreign deletion', async () => {
  await request(app).post('/api/v1/files/images').set('Authorization', bearerA)
    .attach('file', Buffer.from('text'), 'bad.txt').expect(400);
  await request(app).delete('/api/v1/files/images/image-a')
    .set('Authorization', bearerB).expect(403);
});
```

- [ ] **Step 2: Run file tests to verify RED**

Run: `npm.cmd --prefix server test -- files.test.js`  
Expected: FAIL because Multer, storage, and routes do not exist.

- [ ] **Step 3: Implement file validation and local storage**

Configure Multer memory storage with a 10 MiB limit. Validate JPEG/PNG/WEBP magic bytes independently of filename/MIME header. Generate `posts/YYYY/MM/<uuid>.<ext>`, write under `APP_STORAGE_ROOT/uploads`, create a `TEMPORARY` image row belonging to the current user, and serve public URLs through Nginx. Implement deletion only for the owning user and only before attachment.

- [ ] **Step 4: Run file tests to verify GREEN**

Run: `npm.cmd --prefix server test -- files.test.js`  
Expected: PASS for valid PNG, type/size rejection, and deletion authorization.

### Task 4: Post publishing, list, and detail

**Files:**
- Create: `server/src/posts/post.repository.js`
- Create: `server/src/posts/post.service.js`
- Create: `server/src/posts/post.routes.js`
- Create: `server/test/posts.test.js`
- Modify: `server/src/app.js`

**Interfaces:**
- `POST /api/v1/posts` receives a title, description, kind, category, location, campus, contact, and ordered `imageIds`.
- `GET /api/v1/posts` returns stable paged summaries; `GET /api/v1/posts/:id` returns image URLs and owner display data.
- `PostService.createPost(userId, draft)` owns the transaction that attaches uploaded images.

- [ ] **Step 1: Write failing post-flow tests**

```js
test('creates a post with the current user temporary image and returns it in list/detail', async () => {
  const created = await request(app).post('/api/v1/posts').set('Authorization', bearerA)
    .send({ title: '蓝色水杯', description: '图书馆遗失', kind: 'LOST_NOTICE',
      category: '日用品', location: '图书馆', campus: '主校区', contact: '站内联系', imageIds: ['image-a'] })
    .expect(201);
  const detail = await request(app).get('/api/v1/posts/' + created.body.data.id)
    .set('Authorization', bearerB).expect(200);
  assert.equal(detail.body.data.images[0].id, 'image-a');
});
```

- [ ] **Step 2: Run post tests to verify RED**

Run: `npm.cmd --prefix server test -- posts.test.js`  
Expected: FAIL because post module does not exist.

- [ ] **Step 3: Implement validation and transaction**

Validate title 1–80 characters, description 1–2000 characters, non-empty category/location/campus/contact, valid kind (`LOST_NOTICE` or `SEARCH_NOTICE`), and at most six images. In one transaction create the post, verify each image is temporary and owned by current user, mark it `ATTACHED`, and attach it in requested order. Lists use `created_at DESC, id DESC`.

- [ ] **Step 4: Run post tests to verify GREEN**

Run: `npm.cmd --prefix server test -- posts.test.js`  
Expected: PASS for create/list/detail, image URL display data, and foreign-upload rejection.

### Task 5: Claims, clues, and owner-confirmed return

**Files:**
- Create: `server/src/claims/claim.repository.js`
- Create: `server/src/claims/claim.service.js`
- Create: `server/src/claims/claim.routes.js`
- Create: `server/test/claims.test.js`
- Modify: `server/src/app.js`

**Interfaces:**
- `POST /api/v1/posts/:id/claims`, `POST /api/v1/posts/:id/clues`.
- Owner-only reads: `GET /api/v1/posts/:id/claims`, `GET /api/v1/posts/:id/clues`.
- `PATCH /api/v1/claims/:id/return` performs the only phase-one transition: claim `PENDING → COMPLETED`, post `ACTIVE → RESOLVED`.

- [ ] **Step 1: Write failing core-flow tests**

```js
test('A confirms B claim exactly once and resolves the post', async () => {
  const claim = await request(app).post('/api/v1/posts/post-a/claims').set('Authorization', bearerB)
    .send({ answer: '杯底有一处划痕' }).expect(201);
  await request(app).patch('/api/v1/claims/' + claim.body.data.id + '/return')
    .set('Authorization', bearerA).expect(200);
  await request(app).patch('/api/v1/claims/' + claim.body.data.id + '/return')
    .set('Authorization', bearerA).expect(409);
  await request(app).patch('/api/v1/claims/' + claim.body.data.id + '/return')
    .set('Authorization', bearerB).expect(403);
});
```

- [ ] **Step 2: Run claim tests to verify RED**

Run: `npm.cmd --prefix server test -- claims.test.js`  
Expected: FAIL because claim/clue routes do not exist.

- [ ] **Step 3: Implement ownership rules and conditional transition**

Claims require active `LOST_NOTICE`, non-owner requester, and 1–500 answer characters. Clues require active `SEARCH_NOTICE`, non-owner requester, and 1–500 characters. Owner-only list queries enforce post ownership. Confirm return uses a transaction and a status-conditioned update; a second completion returns 409. Do not add approval/rejection routes.

- [ ] **Step 4: Run claim tests to verify GREEN**

Run: `npm.cmd --prefix server test -- claims.test.js`  
Expected: PASS for A → B → A completion, clue visibility, self-action rejection, and authorization boundaries.

### Task 6: HarmonyOS API boundary and phase-one reactive integration

**Files:**
- Modify: `entry/src/main/module.json5`
- Create: `entry/src/main/ets/services/api/ApiTypes.ets`
- Create: `entry/src/main/ets/services/api/ApiClient.ets`
- Create: `entry/src/main/ets/services/api/AuthApiRepository.ets`
- Create: `entry/src/main/ets/services/api/FileApiRepository.ets`
- Create: `entry/src/main/ets/services/api/ContentApiRepository.ets`
- Create: `entry/src/main/ets/services/ImagePickerService.ets`
- Modify: `entry/src/main/ets/services/AccountRepository.ets`
- Modify: `entry/src/main/ets/services/ContentRepository.ets`
- Modify: `entry/src/main/ets/stores/AuthStore.ets`
- Modify: `entry/src/main/ets/stores/AppStore.ets`
- Modify: `entry/src/main/ets/pages/Index.ets`
- Modify: `entry/src/main/ets/models/AppModels.ets`
- Modify: `entry/src/test/AppStore.test.ets`
- Create: `entry/src/test/ApiRepository.test.ets`
- Modify: `entry/src/test/List.test.ets`

**Interfaces:**
- `ApiClient.request<T>(method, path, body?, token?): Promise<ApiResponse<T>>`.
- `AuthApiRepository.login(account, password): Promise<LoginResult>`.
- `FileApiRepository.uploadImage(uri, token): Promise<UploadedImage>`.
- `ContentApiRepository.listPosts(), createPost(), getPost(), createClaim(), createClue(), confirmReturn()`.

- [ ] **Step 1: Write failing ArkTS repository/store tests**

```ts
it('clears the local session after a 401 response', async () => {
  const client = new FakeApiClient({ code: 'AUTH_UNAUTHORIZED', message: '登录已过期' });
  const store = new AuthStore(new AuthApiRepository(client));
  await store.handleUnauthorized();
  expect(store.currentAccount).assertUndefined();
});
```

- [ ] **Step 2: Run ArkTS tests to verify RED**

Run: the existing Hvigor unit-test command.  
Expected: new tests fail because client repositories and 401 handling are absent.

- [ ] **Step 3: Implement client HTTP and screen wiring**

Add `ohos.permission.INTERNET`. Use `PhotoViewPicker` from `@kit.MediaLibraryKit` with image-only selection and no more than six items. Persist only access token and basic displayed profile; do not persist password, server hashes, or mock account collections for API-backed login. Convert login, list refresh, publish, detail, claim/clue, and confirm-return paths to await repositories and immediately replace store state from response DTOs. On 401 clear the local token and route UI to login. Leave excluded Mock-only features explicitly unavailable rather than partially switched.

- [ ] **Step 4: Run ArkTS tests to verify GREEN**

Run: the same Hvigor unit-test command.  
Expected: zero failed tests; API/store behavior is covered without a connected device.

### Task 7: End-to-end validation and delivery documentation

**Files:**
- Create: `server/test/core-flow.integration.test.js`
- Create: `deploy/verify-core-flow.sh`
- Modify: `README.md`
- Modify: `TESTING.md`

**Interfaces:**
- The verifier invokes health endpoints and the complete A/B core flow without printing access tokens.
- README documents safe Linux deployment, SQL import, Knex migration, volume backup, and rollback boundaries.

- [ ] **Step 1: Write failing integration test**

```js
test('A publishes an image, B claims it, and A confirms return', async () => {
  const a = await login('13800000001', 'Campus123');
  const image = await uploadTinyPng(a.token);
  const post = await createPost(a.token, image.id);
  const b = await login('13800000002', 'Teacher123');
  const claim = await createClaim(b.token, post.id);
  await confirmReturn(a.token, claim.id);
  assert.equal((await getPost(b.token, post.id)).status, 'RESOLVED');
});
```

- [ ] **Step 2: Run test to verify RED**

Run: `npm.cmd --prefix server test -- core-flow.integration.test.js`  
Expected: FAIL until all API modules are composed.

- [ ] **Step 3: Add deployment handoff and verifier**

Document only environment variable names in the repository template. Explain schema-only versus development seed import, container start/health commands, upload volume backup, and manual rollback. The shell verifier exits non-zero on bad health/API responses and uses JSON parsing without echoing bearer tokens.

- [ ] **Step 4: Run final validations**

Run:

```powershell
npm.cmd --prefix server test
docker compose -f deploy/compose.yaml --env-file deploy/.env.example config
```

Then run the existing ArkTS unit-test command and CompileArkTS command. Expected: server tests pass, Compose validates, ArkTS tests report zero failures, and CompileArkTS succeeds. If Docker daemon, MySQL, or a device is unavailable, report that exact validation as pending rather than successful.
