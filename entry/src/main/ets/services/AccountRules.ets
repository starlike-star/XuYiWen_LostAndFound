import { IdentityRole } from '../models/AccountModels';

export const SCHOOL_EMAIL_SUFFIX: string = '@campus.edu.cn';

export function validatePassword(password: string): boolean {
  if (password.length < 8 || password.length > 20) {
    return false;
  }
  return /[A-Za-z]/.test(password) && /[0-9]/.test(password);
}

export function validateSchoolEmail(email: string): boolean {
  const normalized: string = email.trim().toLowerCase();
  return normalized.length > SCHOOL_EMAIL_SUFFIX.length && normalized.endsWith(SCHOOL_EMAIL_SUFFIX);
}

export function validatePhone(phone: string): boolean {
  return /^1[3-9][0-9]{9}$/.test(phone.trim());
}

export function validateNickname(nickname: string): boolean {
  const value: string = nickname.trim();
  return value.length >= 2 && value.length <= 16;
}

export function validateRoleFields(role: IdentityRole, realName: string, identityNumber: string,
  department: string, grade: string): string {
  if (realName.trim().length === 0) {
    return '请填写真实姓名';
  }
  if (identityNumber.trim().length === 0) {
    return role === IdentityRole.STUDENT ? '请填写学号' : '请填写工号';
  }
  if (department.trim().length === 0) {
    return role === IdentityRole.STAFF ? '教职工必须填写所属部门' : '请填写所在院系';
  }
  if (role === IdentityRole.STUDENT && grade.trim().length === 0) {
    return '学生必须填写入学年份';
  }
  return '';
}

export function roleLabel(role: IdentityRole): string {
  if (role === IdentityRole.TEACHER) {
    return '教师';
  }
  if (role === IdentityRole.STAFF) {
    return '教职工';
  }
  return '学生';
}

