import { Router } from 'express';
import { success } from '../common/api-response.js';

export function createNotificationRouter(service) {
  const router = Router();
  router.get('/notifications', async (request, response, next) => {
    try {
      success(request, response, await service.list(request.auth.userId));
    } catch (error) {
      next(error);
    }
  });
  router.put('/notifications/read', async (request, response, next) => {
    try {
      success(request, response, await service.markRead(request.auth.userId, request.body?.notificationIds));
    } catch (error) {
      next(error);
    }
  });
  return router;
}
