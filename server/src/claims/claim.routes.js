import { Router } from 'express';
import { success } from '../common/api-response.js';

export function createClaimRouter(service) {
  const router = Router();
  router.post('/posts/:id/claims', async (request, response, next) => {
    try { success(request, response, await service.createClaim(request.auth.userId, request.params.id, request.body?.answer), 201); } catch (error) { next(error); }
  });
  router.post('/posts/:id/clues', async (request, response, next) => {
    try { success(request, response, await service.createClue(request.auth.userId, request.params.id, request.body?.content), 201); } catch (error) { next(error); }
  });
  router.get('/posts/:id/claims', async (request, response, next) => {
    try { success(request, response, await service.listClaims(request.auth.userId, request.params.id)); } catch (error) { next(error); }
  });
  router.get('/posts/:id/clues', async (request, response, next) => {
    try { success(request, response, await service.listClues(request.auth.userId, request.params.id)); } catch (error) { next(error); }
  });
  router.patch('/claims/:id/return', async (request, response, next) => {
    try { success(request, response, await service.confirmReturn(request.auth.userId, request.params.id)); } catch (error) { next(error); }
  });
  return router;
}
