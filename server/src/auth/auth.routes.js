import { Router } from 'express';
import { success } from '../common/api-response.js';

export function createAuthRouter(service) {
  const router = Router();
  router.post('/login/password', async (request, response, next) => {
    try {
      success(request, response, await service.login(request.body?.account, request.body?.password));
    } catch (error) {
      next(error);
    }
  });
  return router;
}
