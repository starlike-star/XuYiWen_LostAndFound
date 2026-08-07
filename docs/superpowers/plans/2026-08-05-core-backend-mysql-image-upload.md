# Core Backend, MySQL, and Image Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a locally deployable Linux core flow: password login, image upload, post publishing/list/detail, claim or clue submission, and owner-confirmed return.

**Architecture:** A Spring Boot 3 / Java 21 Maven API uses Flyway and MySQL 8. Repository interfaces isolate persistence and a `StorageService` isolates local files from future OBS. The HarmonyOS client calls repositories through a shared API client and keeps ArkUI state in the existing stores.

**Tech Stack:** HarmonyOS ArkTS/API 24, Spring Boot 3, Java 21, Maven, MyBatis, Flyway, MySQL 8, Docker Compose, Nginx.

## Global Constraints

- First phase supports password login only; do not implement phone/email verification codes, refresh tokens, admin APIs, notifications, favorites, likes, comments, or complex claim review.
- The client must never connect to MySQL directly.
- Image URLs are derived from storage object keys; do not persist client local paths or raw upload filenames.
- Store production secrets only in environment variables or container secrets; never create `.env` with usable passwords, JWT keys, or certificates.
- `database/02_seed_dev.sql` is for development only and must not be referenced by production deployment commands.
- The repository is not a Git repository; do not create branches or commits.
- Do not generate a HAP unless the user specifically requests it.

---

### Task 1: Database contract, Maven service skeleton, and local deployment

**Files:**
- Create: `database/01_schema.sql`
- Create: `database/02_seed_dev.sql`
- Create: `server/pom.xml`
- Create: `server/src/main/resources/application.yml`
- Create: `server/src/main/resources/db/migration/V1__core_schema.sql`
- Create: `server/src/main/resources/db/migration/V2__seed_dev.sql`
- Create: `server/src/main/java/cn/edu/campus/lostfound/LostFoundApplication.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/common/ApiResponse.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/common/ApiExceptionHandler.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/config/WebConfig.java`
- Create: `deploy/compose.yaml`
- Create: `deploy/nginx.conf`
- Create: `deploy/.env.example`
- Create: `server/Dockerfile`

**Interfaces:**
- Produces MySQL tables `users`, `user_credentials`, `sessions`, `posts`, `post_images`, `claims`, and `clues`.
- Produces API envelope `ApiResponse<T> { code, message, data, requestId }` and health endpoints `/health/live`, `/health/ready`.
- Later tasks consume `DATABASE_URL`, `APP_JWT_SECRET`, and `APP_STORAGE_ROOT` as environment variables.

- [ ] **Step 1: Write schema verification tests before production code**

Create `server/src/test/java/cn/edu/campus/lostfound/SchemaMigrationTest.java`, configured with Testcontainers MySQL, that asserts Flyway creates all seven tables and that duplicate phone insertion fails. The test must query `information_schema.tables` and execute two inserts into `user_credentials` with the same phone.

- [ ] **Step 2: Run schema test to verify RED**

Run: `mvn -q -f server/pom.xml -Dtest=SchemaMigrationTest test`

Expected: FAIL because the Maven module, migrations, and database tables do not exist.

- [ ] **Step 3: Create schema and deployment skeleton**

Use `utf8mb4` / `utf8mb4_0900_ai_ci`, InnoDB, UTC timestamps, `CHAR(36)` UUID IDs, and explicit foreign keys. `posts.status` allows `ACTIVE`, `CLAIMING`, `RESOLVED`, `CLOSED`; `claims.status` allows `PENDING`, `COMPLETED`. Store media in `post_images(object_key, public_url, content_type, size_bytes, status)` where status is `TEMPORARY` or `ATTACHED`.

Configure Flyway to run V1 automatically; keep V2 disabled by default and make `database/02_seed_dev.sql` an explicit developer command. Compose must expose only Nginx on host port 8080, keep MySQL internal, and mount `lostfound_uploads` at `/app/storage`.

- [ ] **Step 4: Run schema test to verify GREEN**

Run: `mvn -q -f server/pom.xml -Dtest=SchemaMigrationTest test`

Expected: PASS, with duplicate phone rejected by the unique constraint.

- [ ] **Step 5: Validate deployment configuration without starting production services**

Run: `docker compose -f deploy/compose.yaml --env-file deploy/.env.example config`

Expected: Compose resolves `mysql`, `api`, and `nginx`; no real secret is printed or committed.

### Task 2: Password authentication and server-side ownership context

**Files:**
- Create: `server/src/main/java/cn/edu/campus/lostfound/auth/AuthController.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/auth/AuthService.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/auth/AuthMapper.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/auth/LoginRequest.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/auth/LoginResponse.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/auth/CurrentUser.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/config/SecurityConfig.java`
- Create: `server/src/test/java/cn/edu/campus/lostfound/auth/AuthControllerTest.java`

**Interfaces:**
- Consumes `users`, `user_credentials`, password hashes, and `APP_JWT_SECRET`.
- Produces `POST /api/v1/auth/login/password` accepting `{ account, password }`, returning `{ accessToken, expiresAt, user }`.
- Produces `CurrentUser.requireId()` for later post/file/claim services.

- [ ] **Step 1: Write failing authentication tests**

Test phone login, normalized school-email login, wrong password, frozen account, deleted account, missing bearer token, and a valid bearer token. Assert the test uses an Argon2/BCrypt hash seeded directly into the test database, not the old client digest algorithm.

- [ ] **Step 2: Run authentication tests to verify RED**

Run: `mvn -q -f server/pom.xml -Dtest=AuthControllerTest test`

Expected: FAIL because the login endpoint and security filter do not exist.

- [ ] **Step 3: Implement minimal authentication boundary**

Resolve `account` by trimmed phone or lower-cased email. Reject non-normal statuses before password verification. Sign a 15-minute access token containing only user ID and role; do not add refresh-token endpoints. Configure `/health/**` and `/api/v1/auth/login/password` as anonymous; all later endpoints require bearer authentication.

- [ ] **Step 4: Run authentication tests to verify GREEN**

Run: `mvn -q -f server/pom.xml -Dtest=AuthControllerTest test`

Expected: PASS, including 401 for protected endpoints without a valid token.

### Task 3: Local image storage with OBS-compatible object-key API

**Files:**
- Create: `server/src/main/java/cn/edu/campus/lostfound/file/StorageService.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/file/LocalStorageService.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/file/FileController.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/file/FileService.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/file/FileMapper.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/file/UploadImageResponse.java`
- Create: `server/src/test/java/cn/edu/campus/lostfound/file/FileControllerTest.java`

**Interfaces:**
- Consumes authenticated user ID and multipart part named `file`.
- Produces `POST /api/v1/files/images` and `DELETE /api/v1/files/images/{id}`.
- `StorageService.save(InputStream, String contentType): StoredObject` returns `{ objectKey, publicUrl, sizeBytes }`; a future OBS implementation keeps this signature.

- [ ] **Step 1: Write failing upload tests**

Test an authenticated PNG upload returns a temporary image ID and a URL under `/uploads/`; reject text files, files over 10 MiB, and delete attempts by a different user. Use `MockMultipartFile` with PNG magic bytes and a temporary test storage directory.

- [ ] **Step 2: Run upload tests to verify RED**

Run: `mvn -q -f server/pom.xml -Dtest=FileControllerTest test`

Expected: FAIL because the multipart endpoint and storage implementation do not exist.

- [ ] **Step 3: Implement local storage and static delivery**

Accept JPEG, PNG, and WEBP only, verify magic bytes before assigning a generated UUID name, and limit one upload to 10 MiB. Store files under `${APP_STORAGE_ROOT}/uploads/posts/YYYY/MM/<uuid>.<extension>`. Insert a `TEMPORARY` row owned by the current user. Serve `/uploads/**` through Nginx from the mounted volume; do not expose a filesystem path in JSON.

- [ ] **Step 4: Run upload tests to verify GREEN**

Run: `mvn -q -f server/pom.xml -Dtest=FileControllerTest test`

Expected: PASS for valid upload, invalid type, size limit, and ownership rejection.

### Task 4: Posts, images, listing, and detail

**Files:**
- Create: `server/src/main/java/cn/edu/campus/lostfound/post/PostController.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/post/PostService.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/post/PostMapper.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/post/CreatePostRequest.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/post/PostSummary.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/post/PostDetail.java`
- Create: `server/src/test/java/cn/edu/campus/lostfound/post/PostControllerTest.java`

**Interfaces:**
- Consumes authenticated user and temporary uploaded image IDs.
- Produces `GET /api/v1/posts?page=&pageSize=&keyword=&kind=&status=`, `POST /api/v1/posts`, and `GET /api/v1/posts/{id}`.
- Produces public image URLs in summary/detail DTOs and marks referenced image rows `ATTACHED` inside the post transaction.

- [ ] **Step 1: Write failing post tests**

Test that an owner creates a `LOST_NOTICE` with one uploaded image, list results expose that image URL, detail returns the owner and image metadata, and another user cannot attach the first user's temporary upload ID.

- [ ] **Step 2: Run post tests to verify RED**

Run: `mvn -q -f server/pom.xml -Dtest=PostControllerTest test`

Expected: FAIL because post API and temporary-image attachment transaction do not exist.

- [ ] **Step 3: Implement post API and transaction**

Validate title 1–80 characters, description 1–2000 characters, category/location non-empty, `kind` one of `LOST_NOTICE` or `SEARCH_NOTICE`, and image count 0–6. Under one transaction create the post, verify all supplied image IDs are `TEMPORARY` and owned by the current user, mark them `ATTACHED`, and insert ordered `post_images` rows. Lists use stable `created_at DESC, id DESC` pagination.

- [ ] **Step 4: Run post tests to verify GREEN**

Run: `mvn -q -f server/pom.xml -Dtest=PostControllerTest test`

Expected: PASS for create, list, detail, public image URL, and foreign-upload rejection.

### Task 5: Minimal claim/clue flow and owner-confirmed return

**Files:**
- Create: `server/src/main/java/cn/edu/campus/lostfound/claim/ClaimController.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/claim/ClaimService.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/claim/ClaimMapper.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/claim/CreateClaimRequest.java`
- Create: `server/src/main/java/cn/edu/campus/lostfound/claim/CreateClueRequest.java`
- Create: `server/src/test/java/cn/edu/campus/lostfound/claim/ClaimControllerTest.java`

**Interfaces:**
- Consumes active posts and `CurrentUser` identity.
- Produces `POST /api/v1/posts/{id}/claims`, `POST /api/v1/posts/{id}/clues`, `GET /api/v1/posts/{id}/claims`, `GET /api/v1/posts/{id}/clues`, and `PATCH /api/v1/claims/{id}/return`.
- The only phase-one state transition is claim `PENDING → COMPLETED` and post `ACTIVE → RESOLVED`.

- [ ] **Step 1: Write failing core-flow tests**

Create two users and one active post. Test B can create a claim on a `LOST_NOTICE`, A can read it and confirm return, the post becomes `RESOLVED`, a second confirm fails, B cannot confirm, and A cannot claim their own post. Separately test B can add a clue to a `SEARCH_NOTICE` and only its owner can list clues.

- [ ] **Step 2: Run claim tests to verify RED**

Run: `mvn -q -f server/pom.xml -Dtest=ClaimControllerTest test`

Expected: FAIL because claim/clue endpoints and conditional update are absent.

- [ ] **Step 3: Implement minimal state transition**

For claim creation require `LOST_NOTICE`, `ACTIVE`, non-owner, and 1–500 answer characters. For clue creation require `SEARCH_NOTICE`, `ACTIVE`, non-owner, and 1–500 content characters. Confirm return with an update conditioned on claim status, post ownership, and post status; if affected row count is not one, return a conflict response. Do not add approval/rejection endpoints.

- [ ] **Step 4: Run claim tests to verify GREEN**

Run: `mvn -q -f server/pom.xml -Dtest=ClaimControllerTest test`

Expected: PASS for the A → B → A core flow and all ownership boundaries.

### Task 6: HarmonyOS HTTP, secure session, and image selection boundary

**Files:**
- Modify: `entry/src/main/module.json5`
- Create: `entry/src/main/ets/services/api/ApiClient.ets`
- Create: `entry/src/main/ets/services/api/ApiTypes.ets`
- Create: `entry/src/main/ets/services/api/SessionRepository.ets`
- Create: `entry/src/main/ets/services/api/AuthApiRepository.ets`
- Create: `entry/src/main/ets/services/api/FileApiRepository.ets`
- Create: `entry/src/main/ets/services/ImagePickerService.ets`
- Modify: `entry/src/main/ets/stores/AuthStore.ets`
- Test: `entry/src/test/AccountRules.test.ets`

**Interfaces:**
- `ApiClient.request<T>(method, path, body?, token?): Promise<ApiResponse<T>>`.
- `AuthApiRepository.login(account, password): Promise<LoginResponse>`.
- `FileApiRepository.uploadImage(uri): Promise<UploadedImage>` and `deleteImage(id): Promise<void>`.
- `ImagePickerService.pickOne(): Promise<SelectedImage | undefined>`.

- [ ] **Step 1: Write client-facing failing tests**

Add tests for normalized password login input and token-clear-on-401 behavior around a fake `ApiClient` response. Keep MockAuthService tests only for legacy local-mode behavior until its callers are removed; do not alter their expected server-independent validation semantics.

- [ ] **Step 2: Run ArkTS tests to verify RED**

Run the existing Hvigor test command. Expected: new repository-facing tests fail because the API session and 401 handling do not exist.

- [ ] **Step 3: Implement client API boundary**

Add `ohos.permission.INTERNET`. Use `photoAccessHelper.PhotoViewPicker` from `@kit.MediaLibraryKit` with `PhotoViewMIMETypes.IMAGE_TYPE` and `maxSelectNumber = 6`, which grants access only to the images selected by the user rather than broad storage access. Load `API_BASE_URL` from a single debug configuration file. On 401, clear the locally stored access token and make `AuthStore.currentAccount` undefined; no refresh-token call is allowed in phase one. Persist only the token and basic displayed user profile, never passwords or the database model.

- [ ] **Step 4: Run ArkTS tests to verify GREEN**

Run the same Hvigor test command and inspect `entry/.test/default/intermediates/test/coverage_data/test_result.txt` for zero failures.

### Task 7: HarmonyOS core screens wired to repositories

**Files:**
- Create: `entry/src/main/ets/services/api/ContentApiRepository.ets`
- Modify: `entry/src/main/ets/stores/AppStore.ets`
- Modify: `entry/src/main/ets/pages/Index.ets`
- Modify: `entry/src/main/ets/models/AppModels.ets`
- Modify: `TESTING.md`

**Interfaces:**
- `ContentApiRepository.listPosts(filter, page): Promise<Page<Post>>`.
- `ContentApiRepository.createPost(draft, imageIds): Promise<Post>`.
- `ContentApiRepository.getPost(id): Promise<PostDetail>`.
- `ContentApiRepository.createClaim(id, answer)`, `createClue(id, content)`, and `confirmReturn(claimId)`.

- [ ] **Step 1: Write failing store tests for server-returned state**

Add focused tests proving that publishing replaces the local post collection with the server post, detail image URLs render from API DTO values, and owner-confirmed return replaces the affected post and claim arrays. Use repository fakes that return complete DTOs; assertions inspect Store-visible state rather than fake invocation counts.

- [ ] **Step 2: Run focused tests to verify RED**

Run the Hvigor unit test command. Expected: new server-repository store tests fail because AppStore is currently synchronous and snapshot-based.

- [ ] **Step 3: Implement phase-one screen integration**

Convert only login, home list, post detail, publish, claim/clue submission, and owner return paths to async repositories. Publish uploads selected images first, then sends returned image IDs with the post request. Detail shows returned image URLs. Remove the corresponding `ContentSnapshot` write path only after these screens no longer call it; leave excluded feature UI explicitly unavailable rather than partially backed by Mock data.

- [ ] **Step 4: Run focused tests to verify GREEN**

Run the Hvigor unit test command and inspect `test_result.txt` for zero failures.

### Task 8: End-to-end local deployment and handoff verification

**Files:**
- Modify: `README.md`
- Modify: `TESTING.md`
- Create: `deploy/verify-core-flow.sh`
- Create: `server/src/test/java/cn/edu/campus/lostfound/CoreFlowIntegrationTest.java`

**Interfaces:**
- Uses deployed `GET /health/live`, `GET /health/ready`, password login, upload, post, claim/clue, and return endpoints.

- [ ] **Step 1: Write failing end-to-end core-flow test**

The integration test must create A/B users, upload a tiny PNG as A, create a post, authenticate B, submit a claim, authenticate A, confirm return, and assert B cannot perform the owner action. The shell verifier must call health endpoints before declaring the stack available.

- [ ] **Step 2: Run integration test to verify RED**

Run: `mvn -q -f server/pom.xml -Dtest=CoreFlowIntegrationTest test`

Expected: FAIL until all auth, file, post, and claim components are wired.

- [ ] **Step 3: Complete deployment documentation and verifier**

Document local Linux prerequisites, safe `.env` creation outside version control, schema-only versus development seed commands, Docker Compose start order, health URLs, upload volume backup, and rollback by restoring the prior database backup and image volume. `verify-core-flow.sh` must fail on a non-2xx health endpoint and must not print tokens.

- [ ] **Step 4: Run final verification**

Run, in order:

```bash
mvn -q -f server/pom.xml test
docker compose -f deploy/compose.yaml --env-file deploy/.env.example config
docker compose -f deploy/compose.yaml up -d --build
./deploy/verify-core-flow.sh
```

Then run the Hvigor test command and `default@CompileArkTS`. Expected: server tests pass, the health/core-flow verifier succeeds, ArkTS tests report zero failures, and CompileArkTS reports `BUILD SUCCESSFUL`. If no device is connected, report that manual mobile image-picker validation remains pending.
