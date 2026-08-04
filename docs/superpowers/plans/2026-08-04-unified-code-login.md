# Unified Phone and Email Code Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow every eligible account to request and use a one-time login code through either its bound phone number or school email, with no password UI in code mode.

**Architecture:** Keep verification challenges in `MockAuthService`, but make login-code issuance account-aware and make code login resolve accounts by either normalized phone or email. Keep `AuthStore` as the observable adapter and simplify `AuthPage` to two user-facing modes with separate password/code state.

**Tech Stack:** HarmonyOS ArkTS, ArkUI V1 state management, Hypium unit tests, Hvigor.

## Global Constraints

- Do not add dependencies or change SDK/build configuration.
- Do not change the persisted `UserAccount` shape or require migration.
- Do not connect a real SMS or email provider; continue showing a local demo code.
- Do not generate a HAP.
- The workspace is not a Git repository, so commit steps are intentionally omitted.

---

### Task 1: Account-aware phone/email verification-code service

**Files:**
- Modify: `entry/src/main/ets/models/AccountModels.ets`
- Modify: `entry/src/main/ets/services/MockAuthService.ets`
- Test: `entry/src/test/AccountRules.test.ets`

**Interfaces:**
- Consumes: `UserAccount.phone`, `UserAccount.email`, `AccountStatus`, `VerificationPurpose.LOGIN`.
- Produces: `LoginMethod.PASSWORD`, `LoginMethod.CODE`; `sendVerificationCode(target, LOGIN)` rejects invalid, missing, frozen, or deleted accounts; `login(CODE, target, code)` accepts normalized phone or email.

- [ ] **Step 1: Write failing tests for phone and email code login**

Add tests that request a real code from `MockAuthService`, pass the returned literal value into `login`, and assert that the returned account ID is `student-1` for both `13800000001` and ` Student@Campus.Edu.Cn `.

- [ ] **Step 2: Write failing tests for issuance constraints and code isolation**

Assert that unknown targets return `ok === false`, frozen/deleted accounts receive no usable login code, and a phone-issued code cannot authenticate the same account through its email target.

- [ ] **Step 3: Run tests and verify RED**

Run:

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:Path='C:\Program Files\Huawei\DevEco Studio\tools\node;' + $env:Path
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p product=default -p module=entry@default -p buildMode=debug test --no-daemon --no-incremental
```

Then inspect `entry/.test/default/intermediates/test/coverage_data/test_result.txt`. Expected: the new email-code and issuance-constraint tests fail for missing behavior.

- [ ] **Step 4: Implement minimal service changes**

Replace method-specific phone lookup with normalized target lookup:

```arkts
private findAccount(value: string): UserAccount | undefined {
  const normalized: string = this.normalizeTarget(value);
  return normalized.includes('@')
    ? this.accounts.find((item: UserAccount) => item.email.toLowerCase() === normalized)
    : this.accounts.find((item: UserAccount) => item.phone === normalized);
}
```

For `VerificationPurpose.LOGIN`, validate phone/email format, find the bound account, reject `FROZEN`/`DELETED`, then issue the challenge for the normalized target. In code login, verify against the exact normalized target entered by the user.

- [ ] **Step 5: Run tests and verify GREEN**

Run the same test command and confirm `Failure: 0, Error: 0` in `test_result.txt`.

### Task 2: Separate password and code login UI state

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets`
- Test: `entry/src/test/AccountRules.test.ets` (service contract remains the automated boundary)

**Interfaces:**
- Consumes: `AuthStore.sendCode`, `AuthStore.login`, `LoginMethod.PASSWORD`, `LoginMethod.CODE`.
- Produces: two login tabs; password mode has account/password fields; code mode has phone-or-email/code fields and keeps the default student target.

- [ ] **Step 1: Replace the three method buttons with two explicit modes**

Use “密码登录” and “验证码登录”. Password mode account placeholder is “请输入手机号或学校邮箱”; code mode uses the same target description.

- [ ] **Step 2: Separate component state**

Keep independent `passwordAccount`, `password`, `codeAccount`, and `loginCode` state. Initialize password and code targets to `13800000001`; never copy password content into `loginCode` and never clear `codeAccount` when switching.

- [ ] **Step 3: Render mode-specific credential controls**

Password mode renders only a password input with `InputType.Password`. Code mode renders only a six-digit code input with normal/numeric-compatible input and the “获取演示验证码” control.

- [ ] **Step 4: Wire each mode to the correct service contract**

Password mode calls `store.login(LoginMethod.PASSWORD, passwordAccount, password)`. Code mode calls `store.login(LoginMethod.CODE, codeAccount, loginCode)` and requests `store.sendCode(codeAccount, VerificationPurpose.LOGIN)`.

- [ ] **Step 5: Update demo copy**

Show the default student as `13800000001 / lin@campus.edu.cn / Campus123` and clarify that the displayed one-time code is used only in code mode.

### Task 3: Verification and acceptance documentation

**Files:**
- Modify: `TESTING.md`

**Interfaces:**
- Consumes: the completed password/code login behavior.
- Produces: reproducible manual acceptance steps for phone and email code login.

- [ ] **Step 1: Update manual test steps**

Document phone-code login, email-code login, no-password UI check, one-click login, no-refresh code display, invalid target, frozen account, and one-time-code reuse.

- [ ] **Step 2: Run the focused test suite**

Run the Hvigor test command and read `test_result.txt`; do not rely only on Hvigor's process banner.

- [ ] **Step 3: Compile ArkTS**

Run:

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p product=default -p module=entry@default -p buildMode=debug 'default@CompileArkTS' --no-daemon --no-incremental
```

Expected: `BUILD SUCCESSFUL` and exit code `0`.

- [ ] **Step 4: Check device availability**

Run `hdc list targets`. If empty, explicitly report that emulator/real-device interaction remains unverified.
