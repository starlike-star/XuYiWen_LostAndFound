import { Router } from 'express';
import multer from 'multer';
import { success } from '../common/api-response.js';
import { ApiError } from '../common/errors.js';

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024, files: 1 } });

export function createFileRouter(service) {
  const router = Router();
  router.post('/images', upload.single('file'), async (request, response, next) => {
    try {
      const image = await service.upload(request.auth.userId, request.file);
      // HarmonyOS request.uploadFile exposes response headers reliably, while the
      // JSON body is not available on every API level. Keep the body for normal
      // HTTP clients and mirror the DTO in headers for native upload clients.
      response.set({
        'X-Image-Id': image.id,
        'X-Image-Url': image.publicUrl,
        'X-Image-Content-Type': image.contentType,
        'X-Image-Size': String(image.sizeBytes)
      });
      success(request, response, image, 201);
    } catch (error) { next(error); }
  });
  router.delete('/images/:id', async (request, response, next) => {
    try {
      await service.delete(request.auth.userId, request.params.id);
      success(request, response, null, 204);
    } catch (error) { next(error); }
  });
  router.use((error, _request, _response, next) => {
    if (error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE') {
      next(new ApiError('FILE_TOO_LARGE', '图片不能超过 10 MiB', 400));
      return;
    }
    next(error);
  });
  return router;
}
