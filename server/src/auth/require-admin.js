import { ApiError } from '../common/errors.js';

export function requireAdmin(request, _response, next) {
  if (request.auth?.isAdmin !== true) {
    next(new ApiError('AUTH_FORBIDDEN', 'administrator access required', 403));
    return;
  }
  next();
}
