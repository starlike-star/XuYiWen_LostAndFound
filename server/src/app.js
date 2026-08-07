import express from 'express';
import { requestIdMiddleware, success } from './common/api-response.js';
import { errorMiddleware } from './common/errors.js';
import { AuthRepository } from './auth/auth.repository.js';
import { AuthService } from './auth/auth.service.js';
import { createAuthRouter } from './auth/auth.routes.js';
import { requireAuth } from './auth/require-auth.js';
import { requireAdmin } from './auth/require-admin.js';
import { FileRepository } from './files/file.repository.js';
import { FileService } from './files/file.service.js';
import { createFileRouter } from './files/file.routes.js';
import { PostRepository } from './posts/post.repository.js';
import { PostService } from './posts/post.service.js';
import { createPostRouter } from './posts/post.routes.js';
import { createAdminPostRouter } from './posts/admin-post.routes.js';
import { ClaimRepository } from './claims/claim.repository.js';
import { ClaimService } from './claims/claim.service.js';
import { createClaimRouter } from './claims/claim.routes.js';
import { NotificationRepository } from './notifications/notification.repository.js';
import { NotificationService } from './notifications/notification.service.js';
import { createNotificationRouter } from './notifications/notification.routes.js';
import { CommentRepository } from './comments/comment.repository.js';
import { CommentService } from './comments/comment.service.js';
import { createCommentRouter } from './comments/comment.routes.js';

function responseEnvelope(data, requestId = 'local') {
  return {
    code: 'OK',
    message: 'success',
    data,
    requestId
  };
}

export function createApp({ db, storage, jwtSecret = 'development-secret-must-be-overridden' } = {}) {
  const app = express();
  app.use(requestIdMiddleware);
  app.use(express.json({ limit: '1mb' }));

  app.get('/health/live', (request, response) => {
    success(request, response, { status: 'live' });
  });

  app.get('/health/ready', async (request, response, next) => {
    try {
      await db.raw('SELECT 1');
      success(request, response, { status: 'ready' });
    } catch (error) {
      next(error);
    }
  });

  app.use('/uploads', async (request, response, next) => {
    if (!storage?.fetchObject) {
      next();
      return;
    }
    try {
      const objectKey = request.path.replace(/^\//, '');
      const upstream = await storage.fetchObject(objectKey);
      if (!upstream.ok) {
        response.status(upstream.status === 404 ? 404 : 502).end();
        return;
      }
      response.status(upstream.status);
      const contentType = upstream.headers.get('content-type');
      if (contentType) response.type(contentType);
      response.send(Buffer.from(await upstream.arrayBuffer()));
    } catch (error) { next(error); }
  });

  if (db) {
    const auth = new AuthService(new AuthRepository(db), jwtSecret);
    const files = new FileService(new FileRepository(db), storage);
    const posts = new PostService(new PostRepository(db));
    const claims = new ClaimService(new ClaimRepository(db));
    const notifications = new NotificationService(new NotificationRepository(db));
    const comments = new CommentService(new CommentRepository(db));
    const protectedRoute = requireAuth(jwtSecret);
    app.get('/api/v1/posts/public', async (request, response, next) => {
      try {
        success(request, response, await posts.list(request.query));
      } catch (error) {
        next(error);
      }
    });
    app.use('/api/v1/auth', createAuthRouter(auth));
    app.use('/api/v1/files', protectedRoute, createFileRouter(files));
    app.use('/api/v1/posts', protectedRoute, createPostRouter(posts));
    app.use('/api/v1/admin', protectedRoute, requireAdmin, createAdminPostRouter(posts));
    app.use('/api/v1', protectedRoute, createClaimRouter(claims));
    app.use('/api/v1', protectedRoute, createCommentRouter(comments));
    app.use('/api/v1', protectedRoute, createNotificationRouter(notifications));
  }
  app.use(errorMiddleware);

  return app;
}
