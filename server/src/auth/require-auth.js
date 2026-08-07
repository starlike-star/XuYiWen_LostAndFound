import jwt from 'jsonwebtoken';
import { ApiError } from '../common/errors.js';

export function requireAuth(jwtSecret) {
  return (request, _response, next) => {
    const header = request.get('Authorization') ?? '';
    if (!header.startsWith('Bearer ')) {
      next(new ApiError('AUTH_UNAUTHORIZED', '请先登录', 401));
      return;
    }
    try {
      const claims = jwt.verify(header.slice(7), jwtSecret, { algorithms: ['HS256'] });
      request.auth = { userId: claims.sub, role: claims.role, isAdmin: claims.isAdmin === true };
      next();
    } catch {
      next(new ApiError('AUTH_UNAUTHORIZED', '登录已过期，请重新登录', 401));
    }
  };
}
