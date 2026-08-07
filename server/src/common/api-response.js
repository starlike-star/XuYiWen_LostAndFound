import { randomUUID } from 'node:crypto';

export function requestIdMiddleware(request, response, next) {
  request.requestId = request.get('X-Request-Id') ?? randomUUID();
  response.set('X-Request-Id', request.requestId);
  next();
}

export function success(request, response, data, status = 200) {
  response.status(status).json({ code: 'OK', message: 'success', data, requestId: request.requestId });
}

export function failure(request, response, code, message, status) {
  response.status(status).json({ code, message, data: null, requestId: request.requestId });
}
