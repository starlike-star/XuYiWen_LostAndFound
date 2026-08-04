export enum IdentityRole {
  STUDENT = 'STUDENT',
  TEACHER = 'TEACHER',
  STAFF = 'STAFF'
}

export enum AccountStatus {
  NORMAL = 'NORMAL',
  FROZEN = 'FROZEN',
  DELETED = 'DELETED'
}

export enum LoginMethod {
  PASSWORD = 'PASSWORD',
  CODE = 'CODE'
}

export enum VerificationPurpose {
  REGISTER = 'REGISTER',
  LOGIN = 'LOGIN',
  RESET_PASSWORD = 'RESET_PASSWORD',
  BIND_PHONE = 'BIND_PHONE',
  BIND_EMAIL = 'BIND_EMAIL'
}

export interface AuditLog {
  id: string;
  operatorId: string;
  action: string;
  reason: string;
  createdAt: number;
}

export interface UserAccount {
  id: string;
  phone: string;
  email: string;
  passwordSalt: string;
  passwordDigest: string;
  nickname: string;
  realName: string;
  identityNumber: string;
  identityRole: IdentityRole;
  isAdmin: boolean;
  department: string;
  grade: string;
  campus: string;
  contact: string;
  creditScore: number;
  status: AccountStatus;
  createdAt: number;
  activeToken: string;
  frozenReason: string;
  violations: string[];
  auditLogs: AuditLog[];
}

export interface AuthSession {
  token: string;
  accountId: string;
  deviceId: string;
  issuedAt: number;
  renewedAt: number;
  expiresAt: number;
}

export interface VerificationChallenge {
  target: string;
  purpose: VerificationPurpose;
  code: string;
  createdAt: number;
  expiresAt: number;
  resendAt: number;
}

export interface RegisterRequest {
  phone: string;
  email: string;
  nickname: string;
  realName: string;
  identityNumber: string;
  identityRole: IdentityRole;
  department: string;
  grade: string;
  campus: string;
  password: string;
  verificationCode: string;
  agreed: boolean;
}

export interface AuthResult {
  ok: boolean;
  message: string;
  account?: UserAccount;
  session?: AuthSession;
}

export interface CodeResult {
  ok: boolean;
  message: string;
  code: string;
}

export interface ProfileUpdate {
  nickname: string;
  department: string;
  grade: string;
  campus: string;
  contact: string;
}

export interface LoginRequest {
  method: LoginMethod;
  account: string;
  credential: string;
}
