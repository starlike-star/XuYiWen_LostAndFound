import { Router } from 'express';
import { success } from '../common/api-response.js';

export function createPostRouter(service) {
  const router = Router();
  router.get('/', async (request, response, next) => {
    try { success(request, response, await service.list(request.query, request.auth.userId, false)); } catch (error) { next(error); }
  });
  router.post('/', async (request, response, next) => {
    try { success(request, response, await service.create(request.auth.userId, request.body), 201); } catch (error) { next(error); }
  });
  router.put('/:id/like', async (request, response, next) => {
    try {
      const enabled = request.body?.enabled === undefined ? true : request.body.enabled === true;
      success(request, response, await service.setLike(request.params.id, request.auth.userId, enabled));
    } catch (error) { next(error); }
  });
  router.delete('/:id/like', async (request, response, next) => {
    try { success(request, response, await service.setLike(request.params.id, request.auth.userId, false)); } catch (error) { next(error); }
  });
  router.put('/:id/favorite', async (request, response, next) => {
    try {
      const enabled = request.body?.enabled === undefined ? true : request.body.enabled === true;
      success(request, response, await service.setFavorite(request.params.id, request.auth.userId, enabled));
    } catch (error) { next(error); }
  });
  router.delete('/:id/favorite', async (request, response, next) => {
    try { success(request, response, await service.setFavorite(request.params.id, request.auth.userId, false)); } catch (error) { next(error); }
  });
  router.get('/:id', async (request, response, next) => {
    try { success(request, response, await service.detail(request.params.id, request.auth.userId)); } catch (error) { next(error); }
  });
  return router;
}
