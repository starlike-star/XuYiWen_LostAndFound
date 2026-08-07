import { Router } from 'express';
import { success } from '../common/api-response.js';

export function createAdminPostRouter(service) {
  const router = Router();
  router.get('/posts', async (request, response, next) => {
    try { success(request, response, await service.list(request.query, request.auth.userId, true)); } catch (error) { next(error); }
  });
  router.delete('/posts/:id', async (request, response, next) => {
    try { success(request, response, await service.setAdminStatus(request.params.id, 'DELETED')); } catch (error) { next(error); }
  });
  router.put('/posts/:id/restore', async (request, response, next) => {
    try { success(request, response, await service.setAdminStatus(request.params.id, 'ACTIVE')); } catch (error) { next(error); }
  });
  return router;
}
