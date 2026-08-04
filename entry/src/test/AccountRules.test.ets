import { describe, it, expect } from '@ohos/hypium';
import {
  validatePassword,
  validateSchoolEmail,
  validateNickname,
  validateRoleFields
} from '../main/ets/services/AccountRules';
import {
  AccountStatus,
  IdentityRole,
  LoginMethod,
  RegisterRequest,
  UserAccount,
  VerificationPurpose
} from '../main/ets/models/AccountModels';
import { MockAuthService } from '../main/ets/services/MockAuthService';

function createStudent(): UserAccount {
  return {
    id: 'student-1',
    phone: '13800000001',
    email: 'student@campus.edu.cn',
    passwordSalt: 'salt',
    passwordDigest: MockAuthService.digestPassword('Campus123', 'salt'),
    nickname: '小林同学',
    realName: '林同学',
    identityNumber: '20240001',
    identityRole: IdentityRole.STUDENT,
    isAdmin: false,
    department: '计算机学院',
    grade: '2024级',
    campus: '主校区',
    contact: '',
    creditScore: 120,
    status: AccountStatus.NORMAL,
    createdAt: 1,
    activeToken: '',
    frozenReason: '',
    violations: [],
    auditLogs: []
  };
}

export default function accountRulesTest() {
  describe('accountRules', () => {
    it('acceptsOnlyPrdPasswordShape', 0, () => {
      expect(validatePassword('Campus123')).assertTrue();
      expect(validatePassword('12345678')).assertFalse();
      expect(validatePassword('abcdefgh')).assertFalse();
      expect(validatePassword('Abc123')).assertFalse();
    });

    it('acceptsConfiguredSchoolEmail', 0, () => {
      expect(validateSchoolEmail('student@campus.edu.cn')).assertTrue();
      expect(validateSchoolEmail('student@example.com')).assertFalse();
    });

    it('validatesNicknameLength', 0, () => {
      expect(validateNickname('小林同学')).assertTrue();
      expect(validateNickname('林')).assertFalse();
      expect(validateNickname('这是一个超过十六个字符限制的校园昵称')).assertFalse();
    });

    it('requiresRoleSpecificIdentityFields', 0, () => {
      expect(validateRoleFields(IdentityRole.STUDENT, '张同学', '20240002', '计算机学院', '2024级')).assertEqual('');
      expect(validateRoleFields(IdentityRole.STUDENT, '张同学', '20240002', '计算机学院', '')).assertEqual('学生必须填写入学年份');
      expect(validateRoleFields(IdentityRole.TEACHER, '王老师', 'T001', '计算机学院', '')).assertEqual('');
      expect(validateRoleFields(IdentityRole.STAFF, '李老师', 'S001', '保卫处', '')).assertEqual('');
    });

    it('rejectsDuplicateRegistrationFields', 0, () => {
      const service = new MockAuthService([createStudent()], () => 1000);
      const request: RegisterRequest = {
        phone: '13800000001',
        email: '',
        nickname: '新同学',
        realName: '新同学',
        identityNumber: '20240002',
        identityRole: IdentityRole.STUDENT,
        department: '计算机学院',
        grade: '2024级',
        campus: '主校区',
        password: 'Campus123',
        verificationCode: '123456',
        agreed: true
      };
      expect(service.validateRegistration(request)).assertEqual('手机号已注册');
    });

    it('logsInWithPhonePasswordAndRejectsFrozenUser', 0, () => {
      const student = createStudent();
      const service = new MockAuthService([student], () => 1000);
      const success = service.login(LoginMethod.PASSWORD, '13800000001', 'Campus123');
      expect(success.ok).assertTrue();
      student.status = AccountStatus.FROZEN;
      const frozen = service.login(LoginMethod.PASSWORD, '13800000001', 'Campus123');
      expect(frozen.message).assertEqual('账号已冻结');
    });

    it('logsInWithCodeSentToBoundPhoneOrEmail', 0, () => {
      const service = new MockAuthService([createStudent()], () => 1000);
      const phoneCode = service.sendVerificationCode('13800000001', VerificationPurpose.LOGIN);
      const phoneLogin = service.login(LoginMethod.CODE, '13800000001', phoneCode.code);
      expect(phoneLogin.ok).assertTrue();
      expect(phoneLogin.account?.id).assertEqual('student-1');

      const emailCode = service.sendVerificationCode(' Student@Campus.Edu.Cn ', VerificationPurpose.LOGIN);
      const emailLogin = service.login(LoginMethod.CODE, ' student@campus.edu.cn ', emailCode.code);
      expect(emailLogin.ok).assertTrue();
      expect(emailLogin.account?.id).assertEqual('student-1');
    });

    it('rejectsLoginCodeIssuanceForUnknownOrUnavailableAccount', 0, () => {
      const student = createStudent();
      const service = new MockAuthService([student], () => 1000);
      expect(service.sendVerificationCode('13999999999', VerificationPurpose.LOGIN).ok).assertFalse();
      student.status = AccountStatus.FROZEN;
      expect(service.sendVerificationCode(student.email, VerificationPurpose.LOGIN).ok).assertFalse();
      student.status = AccountStatus.DELETED;
      expect(service.sendVerificationCode(student.phone, VerificationPurpose.LOGIN).ok).assertFalse();
    });

    it('doesNotAcceptPhoneCodeForEmailLogin', 0, () => {
      const service = new MockAuthService([createStudent()], () => 1000);
      const phoneCode = service.sendVerificationCode('13800000001', VerificationPurpose.LOGIN);
      const result = service.login(LoginMethod.CODE, 'student@campus.edu.cn', phoneCode.code);
      expect(result.ok).assertFalse();
    });

    it('freezesUserAndWritesAuditLog', 0, () => {
      const student = createStudent();
      const service = new MockAuthService([student], () => 1000);
      expect(service.freezeUser('admin-1', 'student-1', '重复发布虚假信息')).assertEqual('');
      expect(student.status).assertEqual(AccountStatus.FROZEN);
      expect(student.auditLogs.length).assertEqual(1);
      expect(student.auditLogs[0].reason).assertEqual('重复发布虚假信息');
    });

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
      const service = new MockAuthService([createStudent()], () => now);
      const result = service.sendVerificationCode('13800000001', VerificationPurpose.LOGIN);
      now = 301001;
      expect(service.verifyCode('13800000001', VerificationPurpose.LOGIN, result.code)).assertEqual('验证码已过期');
    });

    it('consumesVerificationCodeAfterSuccess', 0, () => {
      const service = new MockAuthService([createStudent()], () => 1000);
      const result = service.sendVerificationCode('13800000001', VerificationPurpose.LOGIN);
      expect(service.verifyCode('13800000001', VerificationPurpose.LOGIN, result.code)).assertEqual('');
      expect(service.verifyCode('13800000001', VerificationPurpose.LOGIN, result.code)).assertEqual('请先获取验证码');
    });

    it('normalizesEmailVerificationTarget', 0, () => {
      const service = new MockAuthService([], () => 1000);
      const result = service.sendVerificationCode(' Student@Campus.Edu.Cn ', VerificationPurpose.BIND_EMAIL);
      expect(service.verifyCode('student@campus.edu.cn', VerificationPurpose.BIND_EMAIL, result.code)).assertEqual('');
    });
  });
}
