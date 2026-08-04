import {
  AccountStatus,
  AuditLog,
  AuthResult,
  AuthSession,
  CodeResult,
  IdentityRole,
  LoginMethod,
  RegisterRequest,
  UserAccount,
  VerificationChallenge,
  VerificationPurpose
} from '../models/AccountModels';
import {
  validateNickname,
  validatePassword,
  validatePhone,
  validateRoleFields,
  validateSchoolEmail
} from './AccountRules';

const SESSION_DURATION: number = 7 * 24 * 60 * 60 * 1000;
const CODE_DURATION: number = 5 * 60 * 1000;
const RESEND_DURATION: number = 60 * 1000;

export class MockAuthService {
  private accounts: UserAccount[];
  private challenges: VerificationChallenge[] = [];
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

  getAccounts(): UserAccount[] {
    return this.accounts;
  }

  static digestPassword(password: string, salt: string): string {
    let hash: number = 2166136261;
    const input: string = `${salt}:${password}`;
    for (let round: number = 0; round < 2048; round++) {
      for (let index: number = 0; index < input.length; index++) {
        hash ^= input.charCodeAt(index) + round;
        hash = Math.imul(hash, 16777619);
      }
    }
    return (hash >>> 0).toString(16).padStart(8, '0');
  }

  static createSalt(seed: string): string {
    return MockAuthService.digestPassword(`${seed}:${Date.now()}`, 'campus-salt');
  }

  private findAccount(value: string): UserAccount | undefined {
    const normalized: string = this.normalizeTarget(value);
    if (normalized.includes('@')) {
      return this.accounts.find((item: UserAccount) => item.email.toLowerCase() === normalized);
    }
    return this.accounts.find((item: UserAccount) => item.phone === normalized);
  }

  private issueSession(account: UserAccount): AuthSession {
    const now: number = this.currentTime();
    const token: string = `${account.id}-${now}-${Math.floor(Math.random() * 1000000)}`;
    account.activeToken = token;
    return {
      token: token,
      accountId: account.id,
      deviceId: 'demo-device',
      issuedAt: now,
      renewedAt: now,
      expiresAt: now + SESSION_DURATION
    };
  }

  sendVerificationCode(target: string, purpose: VerificationPurpose): CodeResult {
    const normalizedTarget: string = this.normalizeTarget(target);
    if (purpose === VerificationPurpose.LOGIN) {
      const validTarget: boolean = normalizedTarget.includes('@') ? validateSchoolEmail(normalizedTarget) :
        validatePhone(normalizedTarget);
      if (!validTarget) {
        return { ok: false, message: '请输入正确的手机号或学校邮箱', code: '' };
      }
      const account: UserAccount | undefined = this.findAccount(normalizedTarget);
      if (account === undefined) {
        return { ok: false, message: '手机号或学校邮箱未注册', code: '' };
      }
      if (account.status === AccountStatus.FROZEN) {
        return { ok: false, message: '账号已冻结', code: '' };
      }
      if (account.status === AccountStatus.DELETED) {
        return { ok: false, message: '账号已注销', code: '' };
      }
    }
    const now: number = this.currentTime();
    const existing: VerificationChallenge | undefined = this.challenges.find((item: VerificationChallenge) =>
      item.target === normalizedTarget && item.purpose === purpose);
    if (existing !== undefined && now < existing.resendAt) {
      return { ok: false, message: '请稍后再发送验证码', code: existing.code };
    }
    const code: string = `${100000 + Math.floor(Math.random() * 900000)}`;
    const challenge: VerificationChallenge = {
      target: normalizedTarget,
      purpose: purpose,
      code: code,
      createdAt: now,
      expiresAt: now + CODE_DURATION,
      resendAt: now + RESEND_DURATION
    };
    this.challenges = this.challenges.filter((item: VerificationChallenge) =>
      item.target !== normalizedTarget || item.purpose !== purpose);
    this.challenges.push(challenge);
    return { ok: true, message: '验证码已生成', code: code };
  }

  verifyCode(target: string, purpose: VerificationPurpose, code: string): string {
    const normalizedTarget: string = this.normalizeTarget(target);
    const challenge: VerificationChallenge | undefined = this.challenges.find((item: VerificationChallenge) =>
      item.target === normalizedTarget && item.purpose === purpose);
    if (challenge === undefined) {
      return '请先获取验证码';
    }
    if (this.currentTime() > challenge.expiresAt) {
      return '验证码已过期';
    }
    if (challenge.code !== code.trim()) {
      return '验证码错误';
    }
    this.challenges = this.challenges.filter((item: VerificationChallenge) => item !== challenge);
    return '';
  }

  validateRegistration(request: RegisterRequest): string {
    const phone: string = request.phone.trim();
    const email: string = request.email.trim().toLowerCase();
    if (phone.length > 0 && !validatePhone(phone)) {
      return '请输入正确的手机号';
    }
    if (email.length > 0 && !validateSchoolEmail(email)) {
      return '请输入学校邮箱';
    }
    if (phone.length === 0 && email.length === 0) {
      return '请输入手机号或学校邮箱';
    }
    if (!validateNickname(request.nickname)) {
      return '昵称须为2~16个字符';
    }
    if (!validatePassword(request.password)) {
      return '密码须为8~20位且包含字母和数字';
    }
    const roleError: string = validateRoleFields(request.identityRole, request.realName,
      request.identityNumber, request.department, request.grade);
    if (roleError.length > 0) {
      return roleError;
    }
    if (!request.agreed) {
      return '请同意用户协议和隐私政策';
    }
    if (phone.length > 0 && this.accounts.some((item: UserAccount) => item.phone === phone)) {
      return '手机号已注册';
    }
    if (email.length > 0 && this.accounts.some((item: UserAccount) =>
      item.email.toLowerCase() === email)) {
      return '邮箱已注册';
    }
    if (this.accounts.some((item: UserAccount) => item.nickname === request.nickname.trim())) {
      return '昵称已存在';
    }
    if (this.accounts.some((item: UserAccount) => item.identityNumber === request.identityNumber.trim())) {
      return request.identityRole === IdentityRole.STUDENT ? '学号已注册' : '工号已注册';
    }
    return '';
  }

  register(request: RegisterRequest): AuthResult {
    const error: string = this.validateRegistration(request);
    if (error.length > 0) {
      return { ok: false, message: error };
    }
    const phone: string = request.phone.trim();
    const email: string = request.email.trim().toLowerCase();
    const target: string = phone.length > 0 ? phone : email;
    const codeError: string = this.verifyCode(target, VerificationPurpose.REGISTER, request.verificationCode);
    if (codeError.length > 0) {
      return { ok: false, message: codeError };
    }
    const salt: string = MockAuthService.createSalt(target);
    const now: number = this.currentTime();
    const account: UserAccount = {
      id: `user-${now}-${this.accounts.length}`,
      phone: phone,
      email: email,
      passwordSalt: salt,
      passwordDigest: MockAuthService.digestPassword(request.password, salt),
      nickname: request.nickname.trim(),
      realName: request.realName.trim(),
      identityNumber: request.identityNumber.trim(),
      identityRole: request.identityRole,
      isAdmin: false,
      department: request.department.trim(),
      grade: request.identityRole === IdentityRole.STUDENT ? request.grade.trim() : '',
      campus: request.campus,
      contact: '',
      creditScore: 20,
      status: AccountStatus.NORMAL,
      createdAt: now,
      activeToken: '',
      frozenReason: '',
      violations: [],
      auditLogs: []
    };
    this.accounts.push(account);
    return { ok: true, message: '注册成功', account: account, session: this.issueSession(account) };
  }

  login(method: LoginMethod, accountValue: string, credential: string): AuthResult {
    const account: UserAccount | undefined = this.findAccount(accountValue);
    if (account === undefined) {
      return { ok: false, message: '账号不存在' };
    }
    if (account.status === AccountStatus.FROZEN) {
      return { ok: false, message: '账号已冻结' };
    }
    if (account.status === AccountStatus.DELETED) {
      return { ok: false, message: '账号已注销' };
    }
    if (method === LoginMethod.CODE) {
      const codeError: string = this.verifyCode(accountValue, VerificationPurpose.LOGIN, credential);
      if (codeError.length > 0) {
        return { ok: false, message: codeError };
      }
    } else if (MockAuthService.digestPassword(credential, account.passwordSalt) !== account.passwordDigest) {
      return { ok: false, message: '密码错误' };
    }
    return { ok: true, message: '登录成功', account: account, session: this.issueSession(account) };
  }

  freezeUser(operatorId: string, targetId: string, reason: string): string {
    if (operatorId === targetId) {
      return '不能冻结自己';
    }
    if (reason.trim().length === 0) {
      return '请填写冻结原因';
    }
    const target: UserAccount | undefined = this.accounts.find((item: UserAccount) => item.id === targetId);
    if (target === undefined) {
      return '用户不存在';
    }
    target.status = AccountStatus.FROZEN;
    target.activeToken = '';
    target.frozenReason = reason.trim();
    this.appendAudit(target, operatorId, '冻结账号', reason.trim());
    return '';
  }

  unfreezeUser(operatorId: string, targetId: string): string {
    const target: UserAccount | undefined = this.accounts.find((item: UserAccount) => item.id === targetId);
    if (target === undefined) {
      return '用户不存在';
    }
    target.status = AccountStatus.NORMAL;
    target.frozenReason = '';
    this.appendAudit(target, operatorId, '解除冻结', '恢复正常登录');
    return '';
  }

  deleteUser(operatorId: string, targetId: string, reason: string): string {
    if (operatorId === targetId) {
      return '不能注销自己';
    }
    const target: UserAccount | undefined = this.accounts.find((item: UserAccount) => item.id === targetId);
    if (target === undefined) {
      return '用户不存在';
    }
    target.status = AccountStatus.DELETED;
    target.activeToken = '';
    this.appendAudit(target, operatorId, '强制注销', reason.trim().length > 0 ? reason.trim() : '严重违规');
    return '';
  }

  setAdmin(operatorId: string, targetId: string, enabled: boolean): string {
    if (operatorId === targetId && !enabled) {
      return '不能降级自己';
    }
    const target: UserAccount | undefined = this.accounts.find((item: UserAccount) => item.id === targetId);
    if (target === undefined) {
      return '用户不存在';
    }
    target.isAdmin = enabled;
    this.appendAudit(target, operatorId, enabled ? '提升为管理员' : '降级为普通用户', '角色权限变更');
    return '';
  }

  private appendAudit(target: UserAccount, operatorId: string, action: string, reason: string): void {
    const now: number = this.currentTime();
    const log: AuditLog = {
      id: `audit-${now}-${target.auditLogs.length}`,
      operatorId: operatorId,
      action: action,
      reason: reason,
      createdAt: now
    };
    target.auditLogs.push(log);
  }
}
