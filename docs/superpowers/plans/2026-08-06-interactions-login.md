# 消息、互动与登录界面优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为现有 LostAndFound 应用增加可持久化的点赞/收藏，修复消息入口与未读角标，分离详情页认领/评论区域，并重构登录页信息层级。

**Architecture:** 使用 MySQL 关系表保存帖子点赞和收藏，通过现有 Express/Knex Repository 架构提供幂等 REST 接口；列表/详情查询按当前用户返回计数和状态。ArkTS 在 `Index`/`UserTabs` 中维护 Tab、未读通知和远程刷新状态，在详情页直接更新互动结果；登录注册继续复用现有 `AuthStore` 和认证接口，只调整页面状态和布局。

**Tech Stack:** HarmonyOS ArkTS、Node.js 22、Express 5、Knex、MySQL 8、现有 hvigor 构建链。

## Global Constraints

- 保持现有 ArkTS、Node.js、Express、Knex、MySQL 技术栈。
- 不新增大型依赖，不修改图片上传和图片存储服务。
- 数据库扩展必须提供可重复执行的 `database/04_interactions.sql` 和 Knex migration。
- 评论本次只做布局与现有本地模型交互修复，不新增评论后端表。
- 互动请求失败必须恢复 UI 原状态并显示错误。
- 不提交或推送 Git，除非用户另行要求。

---

### Task 1: Add interaction database schema

**Files:**
- Create: `database/04_interactions.sql`
- Create: `server/src/db/migrations/202608060001_interactions.js`

**Interfaces:**
- Produces tables `post_likes` and `post_favorites`, each with `(post_id, user_id)` primary key, cascading foreign keys, timestamps, and query indexes.

- [ ] **Step 1: Write the idempotent SQL extension**

  Use `CREATE TABLE IF NOT EXISTS`, `ENGINE=InnoDB`, `utf8mb4`, foreign keys to `posts(id)` and `users(id)`, `ON DELETE CASCADE`, and indexes on `user_id` and `post_id`.

- [ ] **Step 2: Add the Knex migration**

  Create both tables only when absent and drop only these two tables in `down`, preserving all existing core tables.

- [ ] **Step 3: Review SQL and migration syntax**

  Run `node --check server/src/db/migrations/202608060001_interactions.js` and inspect the SQL for repeatability and foreign-key compatibility.

### Task 2: Implement post interaction repository and service behavior

**Files:**
- Modify: `server/src/posts/post.repository.js`
- Modify: `server/src/posts/post.service.js`
- Modify: `server/src/posts/post.routes.js`
- Modify: `server/src/app.js` only if route mounting requires it

**Interfaces:**
- `PostService.list(query, userId)` and `PostService.detail(id, userId)` return `likeCount`, `isLiked`, `favoriteCount`, and `isFavorite`.
- `PostService.setLike(postId, userId, enabled)` and `PostService.setFavorite(postId, userId, enabled)` are idempotent.
- Routes expose `PUT/DELETE /posts/:id/like` and `PUT/DELETE /posts/:id/favorite` before the generic `/:id` route.

- [ ] **Step 1: Add failing service tests**

  Extend `server/test/schema.test.js` or add `server/test/post-interaction.test.js` with a fake repository asserting duplicate enable/disable calls remain successful and that a detail DTO includes the four interaction fields.

- [ ] **Step 2: Run the focused tests and verify failure**

  Run `npm.cmd test -- --test-name-pattern interaction` from `server`; the new assertions should fail before implementation.

- [ ] **Step 3: Add repository queries**

  Add batch interaction loading for list rows and one-post interaction loading for detail. Use `COUNT(*)` grouped by `post_id` and `EXISTS`/user-filtered rows for current-user state. Return false/zero for public requests without a user ID.

- [ ] **Step 4: Add idempotent write methods**

  For enable, use an insert guarded by a prior existence check or MySQL duplicate-safe insert; for disable, delete by both post and user. Verify post existence before changing state and map missing posts to the existing `POST_NOT_FOUND` error.

- [ ] **Step 5: Wire service and routes**

  Pass `request.auth.userId` from authenticated list/detail routes, keep public list behavior unchanged, and return the updated interaction DTO from each write endpoint.

- [ ] **Step 6: Run focused tests and full backend tests**

  Run `npm.cmd test -- --test-name-pattern interaction`, then `npm.cmd test`; all tests must pass.

### Task 3: Update ArkTS API types and remote interaction client

**Files:**
- Modify: `entry/src/main/ets/services/api/ApiTypes.ets`
- Modify: `entry/src/main/ets/services/api/ContentApiRepository.ets`

**Interfaces:**
- `RemotePostSummary` and `RemotePostDetail` carry `likeCount`, `isLiked`, `favoriteCount`, `isFavorite`.
- `ContentApiRepository.setLike(token, postId, enabled)` and `setFavorite(token, postId, enabled)` call the corresponding PUT/DELETE endpoint and return the updated post interaction fields.

- [ ] **Step 1: Add type fields and client methods**

  Preserve optional defaults for old API responses, use the existing `ApiClient`, and choose `http.RequestMethod.PUT` or `http.RequestMethod.DELETE` based on `enabled`.

- [ ] **Step 2: Map interaction fields in `toPost` and `getPost`**

  Default missing counts to zero and booleans to false so existing mock/public payloads remain compatible.

- [ ] **Step 3: Compile-check the ArkTS API layer**

  Run the targeted Hvigor compile after UI integration in Task 4.

### Task 4: Fix notification navigation, unread badge, and read-state flow

**Files:**
- Modify: `entry/src/main/ets/stores/AppStore.ets`
- Modify: `entry/src/main/ets/pages/Index.ets`

**Interfaces:**
- `AppStore.markAllNotificationsRead()` returns whether any unread item changed.
- `UserTabs` accepts `unreadCount` and callbacks for opening/entering messages.

- [ ] **Step 1: Add unread-count and mark-all-read helpers**

  Implement `unreadNotificationCount()` and `markAllNotificationsRead()` using the existing observable array replacement pattern.

- [ ] **Step 2: Preserve remote read IDs across refresh**

  In `Index`, capture read notification IDs before `loadCurrentAccountContent`, apply them to newly loaded remote notifications, and clear them after account changes/logout.

- [ ] **Step 3: Make the home notification icon actionable**

  Replace the static top-right text with a button/clickable stack that switches `UserTabs.selectedTab` to the message tab and renders a red numeric badge when unread count is positive.

- [ ] **Step 4: Mark messages read on Tab entry**

  When `selectedTab` changes to the message index, call `markAllNotificationsRead` and notify `Index` so the persisted-in-session read IDs survive a remote refresh.

- [ ] **Step 5: Keep individual notification navigation**

  Preserve tapping a notification to mark it read and open its post, while ensuring the message page layout remains left-aligned.

### Task 5: Make detail interactions work and separate claims/comments

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets`
- Modify: `entry/src/main/ets/stores/AppStore.ets` only if a small local-state helper is required

**Interfaces:**
- Remote detail toggles call Task 3 methods and update `remotePost` without invoking the full content refresh.
- Local/mock detail toggles retain existing `AppStore` behavior.

- [ ] **Step 1: Add optimistic interaction handlers**

  Snapshot the current `isLiked/isFavorite` and count, update the visible `Post`, call the remote endpoint, then apply the server response; on error restore the snapshot and show the existing detail error message.

- [ ] **Step 2: Replace the current like/favorite callbacks**

  Branch on `accessToken.length > 0`; remote mode must not call `onChanged` after a toggle because that reloads stale post data.

- [ ] **Step 3: Create separate detail cards**

  Put claims/approval controls in a “认领信息” card, and the comment input/send controls in a separate “评论” card below it. Keep only applicable claim/clue actions visible based on post kind and owner identity.

- [ ] **Step 4: Compile and inspect the resulting layout code**

  Confirm all builder branches have explicit widths/padding and no nested component shares the same action row.

### Task 6: Restructure the login page

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets`

**Interfaces:**
- Existing `AuthStore.login`, `register`, and `resetPassword` calls remain unchanged.

- [ ] **Step 1: Make login the only primary mode**

  Render title/subtitle, account input, login-method selector, password/code credential controls, login button, and error panel in that order.

- [ ] **Step 2: Move register and reset to secondary links**

  Add bottom text buttons that switch to registration or reset mode; remove the three-way top-level mode row from the login view.

- [ ] **Step 3: Add return-to-login controls**

  Registration and reset views keep their existing fields/steps and add a clear “返回登录” action that resets transient error state.

- [ ] **Step 4: Compile-check the complete ArkTS module**

  Run the Hvigor `default@CompileArkTS` command and fix only errors caused by this change.

### Task 7: End-to-end verification and handoff

**Files:**
- Modify: `TESTING.md` only if the new interaction acceptance steps are not already documented.

- [ ] **Step 1: Run backend validation**

  Run `npm.cmd test` from `server` and verify zero failures.

- [ ] **Step 2: Run ArkTS validation**

  Run the approved Hvigor compile command and verify `BUILD SUCCESSFUL`.

- [ ] **Step 3: Apply SQL extension in the local MySQL database**

  Execute `database/04_interactions.sql` once and verify both tables, primary keys, foreign keys, and indexes with `SHOW CREATE TABLE`.

- [ ] **Step 4: Perform emulator acceptance**

  Verify message navigation and red unread badge, two-account like/favorite isolation after API restart, claim/comment separation, and the new login hierarchy.

- [ ] **Step 5: Review diff and report residual risks**

  Run `git diff --check`, list modified files, and explicitly report that real-device persistence depends on the SQL extension having been applied.
