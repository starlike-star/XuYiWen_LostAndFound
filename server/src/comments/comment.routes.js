import { Router } from 'express';
import { success } from '../common/api-response.js';

export function createCommentRouter(service) {
  const router = Router();
  router.get('/posts/:id/comments', async (request, response, next) => {
    try { success(request, response, await service.list(request.params.id)); } catch (error) { next(error); }
  });
  router.post('/posts/:id/comments', async (request, response, next) => {
    try {
      success(request, response,
        await service.create(request.auth.userId, request.params.id, request.body?.content), 201);
    } catch (error) { next(error); }
  });
  return router;
}
