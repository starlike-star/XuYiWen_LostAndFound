export class ApiError extends Error {
  constructor(code, message, status) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

export function errorMiddleware(error, request, response, _next) {
  if (error instanceof ApiError) {
    response.status(error.status).json({
      code: error.code, message: error.message, data: null, requestId: request.requestId
    });
    return;
  }
  if (error?.type === 'entity.parse.failed' ||
    (error instanceof SyntaxError && error.status === 400)) {
    response.status(400).json({
      code: 'INVALID_JSON', message: '请求体不是合法 JSON', data: null, requestId: request.requestId
    });
    return;
  }
  console.error('Unhandled request error', {
    requestId: request.requestId,
    name: error?.name,
    message: error?.message,
    stack: error?.stack
  });
  response.status(500).json({
    code: 'INTERNAL_ERROR', message: 'internal server error', data: null, requestId: request.requestId
  });
}
