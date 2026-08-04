# Reliability and Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复认证计时、验证码、持久化、消息已读和认领授权问题，并让账号级内容在应用重启后恢复。

**Architecture:** 保留现有 `AuthStore` 与 `AppStore`，新增只负责 Preferences I/O 的 `ContentRepository`。认证和内容业务保持可单元测试的纯逻辑边界，`Index` 统一编排启动、账号切换、内容加载和保存错误反馈。

**Tech Stack:** HarmonyOS 6.1.1、ArkTS、ArkUI、Preferences、Hypium、Hvigor、CodeGraph。

## Global Constraints

- 沿用当前 Stage 模型、ArkTS、ArkUI、Preferences 和 Hypium，不新增第三方依赖。
- 不更换状态管理、构建系统、SDK 或路由架构。
- 内容数据按账号隔离保存，不实现跨账号共享后端模型。
- 不生成 HAP，不提交、不推送；当前目录不是 Git 仓库。
- 禁止批量删除文件或目录，只修改本计划列出的文件。

## File Structure

- Modify `entry/src/main/ets/models/AppModels.ets`: 定义可持久化内容快照。
- Modify `entry/src/main/ets/services/MockAuthService.ets`: 动态时钟、目标规范化、一次性验证码。
- Modify `entry/src/main/ets/services/AccountRepository.ets`: 日志和可传播的持久化错误。
- Create `entry/src/main/ets/services/ContentRepository.ets`: 账号级内容快照 Preferences I/O。
- Modify `entry/src/main/ets/stores/AuthStore.ets`: 输入规范化与保存失败反馈。
- Modify `entry/src/main/ets/stores/AppStore.ets`: 快照边界、消息已读、所有权校验和昵称修复。
- Modify `entry/src/main/ets/pages/Index.ets`: 启动/重试、内容加载保存、异步错误和状态显示。
- Modify `entry/src/test/AccountRules.test.ets`: 认证回归测试。
- Modify `entry/src/test/AppStore.test.ets`: 内容与权限回归测试。
- Create `docs/testing/reliability-test-flow.md`: 自动化及 DevEco Studio 手工验收流程。

---

### Task 1: Verification Time, Normalization, and One-Time Codes

**Files:**
- Modify: `entry/src/test/AccountRules.test.ets`
- Modify: `entry/src/main/ets/services/MockAuthService.ets`
- Modify: `entry/src/main/ets/stores/AuthStore.ets`

**Interfaces:**
- Consumes: `VerificationPurpose`, `RegisterRequest`, existing `MockAuthService` login/register API.
- Produces: `constructor(accounts: UserAccount[], nowProvider?: () => number)`, normalized verification targets, one-time challenges.

- [ ] **Step 1: Write failing tests for clock progress, expiration, consumption, and normalization**

Add tests using a mutable clock provider:

```arkts
it('allowsVerificationCodeResendAfterCooldown', 0, () => {
  let now: number = 1000;
  const service = new MockAuthService([], () => now);
  expect(service.sendVerificationCode('student@campus.edu.cn', VerificationPurpose.BIND_EMAIL).ok).assertTrue();
  expect(service.sendVerificationCode('student@campus.edu.cn', VerificationPurpose.BIND_EMAIL).ok).assertFalse();
  now = 61000;
  expect(service.sendVerificationCode('student@campus.edu.cn', VerificationPurpose.BIND_EMAIL).ok).assertTrue();
});

it('rejectsExpiredVerificationCode', 0, () => {
  let now: number = 1000;
  const service = new MockAuthService([], () => now);
  const result = service.sendVerificationCode('13800000001', VerificationPurpose.LOGIN);
  now = 301001;
  expect(service.verifyCode('13800000001', VerificationPurpose.LOGIN, result.code)).assertEqual('验证码已过期');
});

it('consumesVerificationCodeAfterSuccess', 0, () => {
  const service = new MockAuthService([], () => 1000);
  const result = service.sendVerificationCode('13800000001', VerificationPurpose.LOGIN);
  expect(service.verifyCode('13800000001', VerificationPurpose.LOGIN, result.code)).assertEqual('');
  expect(service.verifyCode('13800000001', VerificationPurpose.LOGIN, result.code)).assertEqual('请先获取验证码');
});

it('normalizesEmailVerificationTarget', 0, () => {
  const service = new MockAuthService([], () => 1000);
  const result = service.sendVerificationCode(' Student@Campus.Edu.Cn ', VerificationPurpose.BIND_EMAIL);
  expect(service.verifyCode('student@campus.edu.cn', VerificationPurpose.BIND_EMAIL, result.code)).assertEqual('');
});
```

Update existing fixed-time constructors from `new MockAuthService(accounts, 1000)` to `new MockAuthService(accounts, () => 1000)`.

- [ ] **Step 2: Run the suite and verify RED**

Run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:Path='C:\Program Files\Huawei\DevEco Studio\tools\node;' + $env:Path
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p product=default -p module=entry@default -p buildMode=debug test --no-daemon --no-incremental
```

Expected: compilation/test failure because the constructor does not accept a clock provider and successful verification remains reusable.

- [ ] **Step 3: Implement the minimal authentication changes**

Use these production boundaries:

```arkts
private nowProvider: () => number;

constructor(accounts: UserAccount[], nowProvider: () => number = () => Date.now()) {
  this.accounts = accounts;
  this.nowProvider = nowProvider;
}

private currentTime(): number {
  return this.nowProvider();
}

private normalizeTarget(target: string): string {
  const value: string = target.trim();
  return value.includes('@') ? value.toLowerCase() : value;
}
```

Every send, verify, session and audit operation reads `currentTime()` at operation time. `verifyCode` removes the matching challenge after successful comparison:

```arkts
this.challenges = this.challenges.filter((item: VerificationChallenge) => item !== challenge);
return '';
```

In `AuthStore`, normalize phone with `trim()` and email with `trim().toLowerCase()` before lookup, duplicate checks, verification and assignment. `sendCode` passes the trimmed/lowercased target when it contains `@`.

- [ ] **Step 4: Run tests and verify GREEN**

Run the Task 1 command. Expected: all existing and new authentication tests pass.

---

### Task 2: Content Snapshot and Business Authorization

**Files:**
- Modify: `entry/src/main/ets/models/AppModels.ets`
- Modify: `entry/src/test/AppStore.test.ets`
- Modify: `entry/src/main/ets/stores/AppStore.ets`

**Interfaces:**
- Produces: `ContentSnapshot`, `AppStore.toSnapshot()`, `AppStore.fromSnapshot()`, `markNotificationRead()`, authorized `reviewClaim()` and `confirmReturn()`.
- Consumes: existing `Post`, `ClaimRequest`, `ClueRecord`, `AppNotification` types.

- [ ] **Step 1: Write failing store tests**

Import the wished-for `ContentSnapshot`/store APIs and add tests whose literal assertions catch missing state or authorization:

```arkts
it('roundTripsContentSnapshotWithoutSharedReferences', 0, () => {
  const original = AppStore.createDemo('student-1', '小林同学');
  original.toggleFavorite('post-1');
  original.addComment('post-1', '小林同学', '我可以提供手机壳特征');
  const snapshot = original.toSnapshot();
  const restored = AppStore.fromSnapshot('student-1', snapshot);
  restored.posts[0].title = '修改后的标题';
  expect(snapshot.posts[0].title).assertEqual('黑色手机等待认领');
  expect(restored.favoritePostIds.length).assertEqual(1);
  expect(restored.comments.length).assertEqual(1);
});

it('marksNotificationReadOnlyOnce', 0, () => {
  const store = AppStore.createDemo('student-1', '小林同学');
  expect(store.markNotificationRead('notice-1')).assertTrue();
  expect(store.notifications[0].read).assertTrue();
  expect(store.markNotificationRead('notice-1')).assertFalse();
});

it('rejectsClaimReviewByNonOwner', 0, () => {
  const store = AppStore.createDemo('student-1', '小林同学');
  const claimId = store.submitClaim('post-1', '手机壳内侧有校园卡贴纸');
  expect(store.reviewClaim('student-2', claimId, true)).assertEqual('无权审核该认领申请');
  expect(store.posts[0].status).assertEqual(PostStatus.ACTIVE);
});

it('usesCurrentAccountNameForOwnedDemoPost', 0, () => {
  const store = AppStore.createDemo('teacher-1', '王老师');
  expect(store.findPost('post-3')?.ownerName).assertEqual('王老师');
});
```

Update the existing approval flow to pass `student-1` as operator ID and assert empty error strings.

- [ ] **Step 2: Run tests and verify RED**

Run the Task 1 test command. Expected: missing snapshot/read APIs and changed authorization signatures cause failure.

- [ ] **Step 3: Implement the snapshot model, cloning, and business guards**

Add the model before implementing the store methods:

```arkts
export interface ContentSnapshot {
  posts: Post[];
  comments: PostComment[];
  claims: ClaimRequest[];
  clues: ClueRecord[];
  notifications: AppNotification[];
  favoritePostIds: string[];
}
```

Add `createDemo(currentUserId: string, currentUserName: string = '小林同学')`. Implement snapshot conversion with explicit array/object copies so restored mutations do not affect the input snapshot.

Use these signatures:

```arkts
static fromSnapshot(currentUserId: string, snapshot: ContentSnapshot): AppStore;
toSnapshot(): ContentSnapshot;
markNotificationRead(notificationId: string): boolean;
reviewClaim(operatorId: string, claimId: string, approved: boolean): string;
confirmReturn(operatorId: string, claimId: string): string;
```

Both claim transitions return `用户不存在`/`认领申请不存在`/`无权审核该认领申请`/`当前状态无法操作` as applicable and mutate only after all guards pass.

- [ ] **Step 4: Run tests and verify GREEN**

Run the Task 1 test command. Expected: all authentication and AppStore tests pass.

---

### Task 3: Observable Account and Content Persistence

**Files:**
- Modify: `entry/src/main/ets/services/AccountRepository.ets`
- Create: `entry/src/main/ets/services/ContentRepository.ets`
- Modify: `entry/src/main/ets/stores/AuthStore.ets`

**Interfaces:**
- Consumes: `ContentSnapshot`, `common.Context`, HarmonyOS Preferences.
- Produces: `ContentRepository.initialize/load/save`, logged and propagated persistence failures.

- [ ] **Step 1: Make AccountRepository failures observable**

Import `BusinessError` and `hilog`, use a dedicated domain/tag, and implement:

```arkts
catch (error) {
  const businessError = error as BusinessError;
  hilog.error(DOMAIN, TAG, 'Preferences operation failed. Code: %{public}d, message: %{public}s',
    businessError.code, businessError.message);
  throw businessError;
}
```

Initialization and writes rethrow. Reads log parse/access failures and return empty/undefined so corrupted optional data does not crash the process.

- [ ] **Step 2: Create ContentRepository**

Implement the exact API:

```arkts
export class ContentRepository {
  private data?: preferences.Preferences;

  async initialize(context: common.Context): Promise<void>;
  load(accountId: string): ContentSnapshot | undefined;
  async save(accountId: string, snapshot: ContentSnapshot): Promise<void>;
}
```

Use Preferences name `campus_lost_found_content` and key `content_${accountId}`. `load` returns `undefined` for missing/malformed data after logging. `save` throws if not initialized or if put/flush fails.

- [ ] **Step 3: Prevent AuthStore from reporting false success**

Keep `persist()` throwing. Wrap each public async mutation that returns `Promise<string>`:

```arkts
try {
  await this.persist();
  return '';
} catch {
  return '数据保存失败，请稍后重试';
}
```

For login/register, do not invoke the page success callback when persistence returns an error. `logout()` continues to reject so the caller can display failure.

- [ ] **Step 4: Run ArkTS compile**

Run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:Path='C:\Program Files\Huawei\DevEco Studio\tools\node;' + $env:Path
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p product=default -p module=entry@default -p buildMode=debug 'default@CompileArkTS' --no-daemon --no-incremental
```

Expected: `BUILD SUCCESSFUL` with no ArkTS type errors.

---

### Task 4: Root Startup, Persistence Orchestration, and UI Corrections

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets`

**Interfaces:**
- Consumes: `ContentRepository`, `AppStore.toSnapshot/fromSnapshot`, authenticated account ID/nickname.
- Produces: retryable startup state, persistent mutations, accurate status/read/authorization UI.

- [ ] **Step 1: Add root startup and content lifecycle state**

Add fields:

```arkts
@State startupError: string = '';
@State operationError: string = '';
private contentRepository: ContentRepository = new ContentRepository();
private contentRepositoryReady: boolean = false;
```

Replace the current `aboutToAppear().then(...)` chain with `initializeApp()` that catches errors, sets `startupError`, and always leaves a renderable loading/error/content state. `loadContentForAccount()` initializes the content repository once, loads `content_${account.id}`, seeds with `AppStore.createDemo(account.id, account.nickname)` when absent, and saves the seed.

- [ ] **Step 2: Persist every successful content mutation**

Implement:

```arkts
private async persistContent(): Promise<void> {
  const account = this.authStore.currentAccount;
  if (account === undefined) {
    return;
  }
  try {
    await this.contentRepository.save(account.id, this.appStore.toSnapshot());
    this.operationError = '';
    this.revision += 1;
  } catch {
    this.operationError = '本次修改未保存，请稍后重试';
    this.revision += 1;
  }
}
```

All current `onChanged: () => this.revision += 1` content callbacks become `onChanged: () => { this.persistContent(); }`. Authentication/profile callbacks retain their existing responsibilities and add rejection feedback.

- [ ] **Step 3: Add startup error UI and retry**

The root branch order becomes loading → startup error → auth/admin/user content. Add a `StartupErrorPage` component showing the error and a retry button invoking `initializeApp()`.

- [ ] **Step 4: Fix message, claim, and status UI**

- Pass `onChanged` into `MessagePage`; click calls `markNotificationRead`, persists when changed, then opens the post.
- Pass `account.id` into `reviewClaim` and `confirmReturn`; display returned error instead of unconditional success.
- Replace the three-way status ternary with an exhaustive helper returning `待认领`、`认领中`、`已归还`、`已关闭`.
- Add `.catch(...)` to login, registration, reset, logout, profile and security Promise chains so rejected storage operations produce visible messages.

- [ ] **Step 5: Run tests and compile**

Run both commands from Tasks 1 and 3. Expected: tests and ArkTS compile succeed.

---

### Task 5: Test Procedure and Final Verification

**Files:**
- Create: `docs/testing/reliability-test-flow.md`
- Verify all files listed in File Structure.

**Interfaces:**
- Consumes: implemented behavior and existing DevEco Studio run workflow.
- Produces: reproducible automatic and manual verification guide.

- [ ] **Step 1: Write the test flow document**

Include prerequisites, exact Hvigor test/compile commands, expected outputs, and numbered DevEco Studio scenarios for cold start, login, content persistence, account isolation, notification read state, verification cooldown/consumption/normalization, claim authorization, closed status, and Preferences failure recovery.

- [ ] **Step 2: Run fresh unit tests**

Run the full test command. Record exit code and the final `BUILD SUCCESSFUL` line.

- [ ] **Step 3: Run fresh ArkTS compile**

Run the compile command. Record exit code and the final `BUILD SUCCESSFUL` line.

- [ ] **Step 4: Re-query CodeGraph**

Query `Index initializeApp ContentRepository AppStore toSnapshot reviewClaim MockAuthService verifyCode` and confirm the index shows the new startup, persistence and authorization call paths without a stale-index warning.

- [ ] **Step 5: Inspect the final scope**

Confirm only planned source/test/document files changed. Because the directory is not a Git repository, report that `git status`, branch, commit and push state are unavailable; do not claim a clean worktree.

- [ ] **Step 6: Report runtime limitations**

Run `hdc list targets`. If empty, state that device/manual scenarios remain unverified and provide the exact test flow; do not claim visual or device persistence success.
