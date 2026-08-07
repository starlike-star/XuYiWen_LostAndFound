import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { ApiError } from '../common/errors.js';

const TOKEN_SECONDS = 15 * 60;

export class AuthService {
  constructor(repository, jwtSecret) {
    this.repository = repository;
    this.jwtSecret = jwtSecret;
  }

  async login(account, password) {
    if (typeof account !== 'string' || typeof password !== 'string' || !account.trim() || !password) {
      throw new ApiError('AUTH_INVALID_CREDENTIALS', '账号或密码错误', 401);
    }
    const user = await this.repository.findByAccount(account.trim());
    if (!user || user.status !== 'NORMAL' || !(await bcrypt.compare(password, user.password_hash))) {
      throw new ApiError('AUTH_INVALID_CREDENTIALS', '账号或密码错误', 401);
    }
    const expiresAt = new Date(Date.now() + TOKEN_SECONDS * 1000).toISOString();
    const accessToken = jwt.sign({ sub: user.id, role: user.identity_role, isAdmin: Boolean(user.is_admin) }, this.jwtSecret, {
      algorithm: 'HS256', expiresIn: TOKEN_SECONDS
    });
    return {
      accessToken,
      expiresAt,
      user: {
        id: user.id, nickname: user.nickname, phone: user.phone, email: user.email,
        role: user.identity_role, isAdmin: Boolean(user.is_admin), department: user.department, campus: user.campus
      }
    };
  }
}
