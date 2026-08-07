import { common } from '@kit.AbilityKit';
import {
  AccountStatus,
  AuthResult,
  AuthSession,
  CodeResult,
  IdentityRole,
  LoginMethod,
  ProfileUpdate,
  RegisterRequest,
  UserAccount,
  VerificationPurpose
} from '../models/AccountModels';
import { AccountRepository } from '../services/AccountRepository';
import { MockAuthService } from '../services/MockAuthService';
import { validateNickname, validatePassword, validatePhone, validateSchoolEmail } from '../services/AccountRules';
import { ApiClient } from '../services/api/ApiClient';

const SESSION_DURATION: number = 7 * 24 * 60 * 60 * 1000;

@Observed
export class AuthStore {
  accounts: UserAccount[] = [];
  currentAccount?: UserAccount;
  session?: AuthSession;
  demoCode: string = '';
  initialized: boolean = false;
  private repository: AccountRepository = new AccountRepository();
  private service: MockAuthService = new MockAuthService([]);
  private apiClient: ApiClient = new ApiClient();

  async initialize(context: common.Context): Promise<void> {
    await this.repository.initialize(context);
    this.accounts = this.repository.loadAccounts();
    if (this.accounts.length === 0) {
      this.accounts = this.seedAccounts();
      await this.repository.saveAccounts(this.accounts);
    }
    this.service = new MockAuthService(this.accounts);
    this.session = this.repository.loadSession();
    await this.restoreSession();
    this.initialized = true;
  }

  private seedAccounts(): UserAccount[] {
    return [
      this.seedAccount('student-1', '13800000001', 'lin@campus.edu.cn', 'Campus123', '小林同学', '林晓',
        '20240001', IdentityRole.STUDENT, false, '计算机学院', '2024级', '主校区', 120, AccountStatus.NORMAL),
      this.seedAccount('teacher-1', '13800000002', 'wang@campus.edu.cn', 'Teacher123', '王老师', '王敏',
        'T202001', IdentityRole.TEACHER, false, '计算机学院', '', '主校区', 260, AccountStatus.NORMAL),
      this.seedAccount('staff-1', '13800000003', 'security@campus.edu.cn', 'Staff1234', '校园保卫处', '李建国',
        'S201801', IdentityRole.STAFF, false, '保卫处', '', '主校区', 480, AccountStatus.NORMAL),
      this.seedAccount('student-2', '13800000004', 'chen@campus.edu.cn', 'Campus123', '陈同学', '陈晨',
        '20230016', IdentityRole.STUDENT, false, '外国语学院', '2023级', '分校区', 85, AccountStatus.NORMAL),
      this.seedAccount('student-3', '13800000005', 'zhou@campus.edu.cn', 'Campus123', '周同学', '周宁',
        '20220028', IdentityRole.STUDENT, false, '经济管理学院', '2022级', '主校区', 45, AccountStatus.FROZEN),
      this.seedAccount('admin-1', '13900000000', 'admin@campus.edu.cn', 'Admin1234', '系统管理员', '管理员',
        'A00001', IdentityRole.STAFF, true, '信息中心', '', '主校区', 500, AccountStatus.NORMAL)
    ];
  }

  private seedAccount(id: string, phone: string, email: string, password: string, nickname: string,
    realName: string, identityNumber: string, role: IdentityRole, isAdmin: boolean, department: string,
    grade: string, campus: string, creditScore: number, status: AccountStatus): UserAccount {
    const salt: string = MockAuthService.createSalt(id);
    return {
      id: id,
      phone: phone,
      email: email,
      passwordSalt: salt,
      passwordDigest: MockAuthService.digestPassword(password, salt),
      nickname: nickname,
      realName: realName,
      identityNumber: identityNumber,
      identityRole: role,
      isAdmin: isAdmin,
      department: department,
      grade: grade,
      campus: campus,
      contact: '',
      creditScore: creditScore,
      status: status,
      createdAt: Date.now() - 30 * 24 * 60 * 60 * 1000,
      activeToken: '',
      frozenReason: status === AccountStatus.FROZEN ? '重复发布无效信息' : '',
      violations: status === AccountStatus.FROZEN ? ['2026-07-28 重复发布无效信息'] : [],
      auditLogs: []
    };
  }

  async restoreSession(): Promise<void> {
    if (this.session === undefined) {
      return;
    }
    const account: UserAccount | undefined = this.accounts.find((item: UserAccount) =>
      item.id === this.session?.accountId);
    const now: number = Date.now();
    if (account === undefined || account.status !== AccountStatus.NORMAL || this.session.expiresAt <= now) {
      await this.logout();
      return;
    }
    if (this.session.deviceId === 'remote-api') {
      this.currentAccount = account;
      return;
    }
    if (account.activeToken !== this.session.token) {
      await this.logout();
      return;
    }
    this.session.renewedAt = now;
    this.session.expiresAt = now + SESSION_DURATION;
    this.currentAccount = account;
    await this.repository.saveSession(this.session);
  }

  sendCode(target: string, purpose: VerificationPurpose): string {
    const value: string = target.trim();
    const normalized: string = value.includes('@') ? value.toLowerCase() : value;
    const result: CodeResult = this.service.sendVerificationCode(normalized, purpose);
    this.demoCode = result.code;
    return result.message;
  }

  async login(method: LoginMethod, account: string, credential: string): Promise<string> {
    if (method === LoginMethod.PASSWORD) {
      try {
        const remote = await this.apiClient.login(account, credential);
        const localAccount: UserAccount | undefined = this.accounts.find((item: UserAccount) =>
          item.id === remote.user.id);
        if (localAccount === undefined) {
          return '登录成功，但本地用户资料未初始化';
        }
        localAccount.nickname = remote.user.nickname;
        localAccount.phone = remote.user.phone;
        localAccount.email = remote.user.email;
        localAccount.department = remote.user.department;
        localAccount.campus = remote.user.campus;
        localAccount.isAdmin = remote.user.isAdmin;
        localAccount.activeToken = remote.accessToken;
        this.currentAccount = localAccount;
        this.session = {
          token: remote.accessToken,
          accountId: localAccount.id,
          deviceId: 'remote-api',
          issuedAt: Date.now(),
          renewedAt: Date.now(),
          expiresAt: Date.parse(remote.expiresAt)
        };
        await this.repository.saveSession(this.session);
        return '';
      } catch (error) {
        return error instanceof Error ? error.message : '登录失败，请稍后重试';
      }
    }
    const result: AuthResult = this.service.login(method, account, credential);
    if (!result.ok || result.account === undefined || result.session === undefined) {
      return result.message;
    }
    this.currentAccount = result.account;
    this.session = result.session;
    return await this.persistWithMessage();
  }

  async register(request: RegisterRequest): Promise<string> {
    const result: AuthResult = this.service.register(request);
    if (!result.ok || result.account === undefined || result.session === undefined) {
      return result.message;
    }
    this.currentAccount = result.account;
    this.session = result.session;
    return await this.persistWithMessage();
  }

  async logout(): Promise<void> {
    if (this.currentAccount !== undefined) {
      this.currentAccount.activeToken = '';
    }
    this.currentAccount = undefined;
    this.session = undefined;
    await this.persist();
  }

  async updateProfile(update: ProfileUpdate): Promise<string> {
    if (this.currentAccount === undefined) {
      return '请先登录';
    }
    if (!validateNickname(update.nickname)) {
      return '昵称须为2~16个字符';
    }
    const duplicate: UserAccount | undefined = this.accounts.find((item: UserAccount) =>
      item.id !== this.currentAccount?.id && item.nickname === update.nickname.trim());
    if (duplicate !== undefined) {
      return '昵称已存在';
    }
    this.currentAccount.nickname = update.nickname.trim();
    this.currentAccount.department = update.department.trim();
    this.currentAccount.grade = this.currentAccount.identityRole === IdentityRole.STUDENT ? update.grade.trim() : '';
    this.currentAccount.campus = update.campus;
    this.currentAccount.contact = update.contact.trim();
    this.accounts = this.accounts.slice();
    return await this.persistWithMessage();
  }

  async changePassword(oldPassword: string, newPassword: string, verificationCode: string): Promise<string> {
    if (this.currentAccount === undefined) {
      return '请先登录';
    }
    if (!validatePassword(newPassword)) {
      return '新密码须为8~20位且包含字母和数字';
    }
    const oldValid: boolean = MockAuthService.digestPassword(oldPassword, this.currentAccount.passwordSalt) ===
      this.currentAccount.passwordDigest;
    let codeValid: boolean = false;
    if (this.currentAccount.phone.length > 0 && verificationCode.length > 0) {
      codeValid = this.service.verifyCode(this.currentAccount.phone, VerificationPurpose.RESET_PASSWORD,
        verificationCode).length === 0;
    }
    if (!oldValid && !codeValid) {
      return '原密码或手机验证码不正确';
    }
    const salt: string = MockAuthService.createSalt(this.currentAccount.id);
    this.currentAccount.passwordSalt = salt;
    this.currentAccount.passwordDigest = MockAuthService.digestPassword(newPassword, salt);
    this.accounts = this.accounts.slice();
    return await this.persistWithMessage();
  }

  async resetPassword(phone: string, newPassword: string, verificationCode: string): Promise<string> {
    const account: UserAccount | undefined = this.accounts.find((item: UserAccount) => item.phone === phone.trim());
    if (account === undefined) {
      return '账号不存在';
    }
    if (!validatePassword(newPassword)) {
      return '新密码须为8~20位且包含字母和数字';
    }
    const codeError: string = this.service.verifyCode(phone.trim(), VerificationPurpose.RESET_PASSWORD,
      verificationCode);
    if (codeError.length > 0) {
      return codeError;
    }
    const salt: string = MockAuthService.createSalt(account.id);
    account.passwordSalt = salt;
    account.passwordDigest = MockAuthService.digestPassword(newPassword, salt);
    account.activeToken = '';
    this.accounts = this.accounts.slice();
    return await this.persistWithMessage();
  }

  async bindPhone(phone: string, code: string): Promise<string> {
    const normalized: string = phone.trim();
    if (this.currentAccount === undefined || !validatePhone(normalized)) {
      return '请输入正确的手机号';
    }
    if (this.accounts.some((item: UserAccount) => item.id !== this.currentAccount?.id && item.phone === normalized)) {
      return '手机号已绑定其他账号';
    }
    const codeError: string = this.service.verifyCode(normalized, VerificationPurpose.BIND_PHONE, code);
    if (codeError.length > 0) {
      return codeError;
    }
    this.currentAccount.phone = normalized;
    this.accounts = this.accounts.slice();
    return await this.persistWithMessage();
  }

  async bindEmail(email: string, code: string): Promise<string> {
    const normalized: string = email.trim().toLowerCase();
    if (this.currentAccount === undefined || !validateSchoolEmail(normalized)) {
      return '请输入学校邮箱';
    }
    if (this.accounts.some((item: UserAccount) => item.id !== this.currentAccount?.id &&
      item.email.toLowerCase() === normalized)) {
      return '邮箱已绑定其他账号';
    }
    const codeError: string = this.service.verifyCode(normalized, VerificationPurpose.BIND_EMAIL, code);
    if (codeError.length > 0) {
      return codeError;
    }
    this.currentAccount.email = normalized;
    this.accounts = this.accounts.slice();
    return await this.persistWithMessage();
  }

  async deleteSelf(hasOpenPosts: boolean): Promise<string> {
    if (this.currentAccount === undefined) {
      return '请先登录';
    }
    if (hasOpenPosts) {
      return '存在未完结的失物或寻物记录，暂不能注销';
    }
    this.currentAccount.status = AccountStatus.DELETED;
    this.currentAccount.activeToken = '';
    this.accounts = this.accounts.slice();
    this.currentAccount = undefined;
    this.session = undefined;
    return await this.persistWithMessage();
  }

  filteredUsers(role: string, department: string, status: string): UserAccount[] {
    return this.accounts.filter((item: UserAccount) => {
      const roleMatch: boolean = role.length === 0 || item.identityRole === role;
      const departmentMatch: boolean = department.length === 0 || item.department === department;
      const statusMatch: boolean = status.length === 0 || item.status === status;
      return roleMatch && departmentMatch && statusMatch;
    });
  }

  async freezeUser(targetId: string, reason: string): Promise<string> {
    if (this.currentAccount === undefined || !this.currentAccount.isAdmin) {
      return '无管理员权限';
    }
    const error: string = this.service.freezeUser(this.currentAccount.id, targetId, reason);
    if (error.length === 0) {
      this.accounts = this.accounts.slice();
    }
    return error.length > 0 ? error : await this.persistWithMessage();
  }

  async unfreezeUser(targetId: string): Promise<string> {
    if (this.currentAccount === undefined || !this.currentAccount.isAdmin) {
      return '无管理员权限';
    }
    const error: string = this.service.unfreezeUser(this.currentAccount.id, targetId);
    if (error.length === 0) {
      this.accounts = this.accounts.slice();
    }
    return error.length > 0 ? error : await this.persistWithMessage();
  }

  async deleteUser(targetId: string, reason: string): Promise<string> {
    if (this.currentAccount === undefined || !this.currentAccount.isAdmin) {
      return '无管理员权限';
    }
    const error: string = this.service.deleteUser(this.currentAccount.id, targetId, reason);
    if (error.length === 0) {
      this.accounts = this.accounts.slice();
    }
    return error.length > 0 ? error : await this.persistWithMessage();
  }

  async setAdmin(targetId: string, enabled: boolean): Promise<string> {
    if (this.currentAccount === undefined || !this.currentAccount.isAdmin) {
      return '无管理员权限';
    }
    const error: string = this.service.setAdmin(this.currentAccount.id, targetId, enabled);
    if (error.length === 0) {
      this.accounts = this.accounts.slice();
    }
    return error.length > 0 ? error : await this.persistWithMessage();
  }

  private async persist(): Promise<void> {
    await this.repository.saveAccounts(this.accounts);
    await this.repository.saveSession(this.session);
  }

  private async persistWithMessage(): Promise<string> {
    try {
      await this.persist();
      return '';
    } catch {
      return '数据保存失败，请稍后重试';
    }
  }
}
