import crypto from 'node:crypto';
import path from 'node:path';
import { mkdir, rm, writeFile } from 'node:fs/promises';
import express from 'express';
import multer from 'multer';

const port = Number(process.env.PORT || 8081);
const root = process.env.STORAGE_ROOT || '/srv/lostfound/uploads';
const publicBaseUrl = process.env.STORAGE_PUBLIC_BASE_URL || ('http://192.168.137.10:' + port);
const sharedSecret = process.env.STORAGE_SHARED_SECRET;
if (!sharedSecret || sharedSecret.length < 32) throw new Error('STORAGE_SHARED_SECRET must be at least 32 characters');

const app = express();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024, files: 1 } });
const imageTypes = new Map([['image/jpeg', 'jpg'], ['image/png', 'png'], ['image/webp', 'webp']]);

function signature(method, requestPath, timestamp) {
  return crypto.createHmac('sha256', sharedSecret)
    .update(timestamp + ':' + method + ':' + requestPath).digest('hex');
}

function authorized(request) {
  const timestamp = request.get('X-Storage-Timestamp') || '';
  const supplied = request.get('X-Storage-Signature') || '';
  const age = Math.abs(Date.now() - Number(timestamp));
  const expected = signature(request.method, request.originalUrl.split('?')[0], timestamp);
  const valid = Number.isFinite(Number(timestamp)) && age <= 5 * 60 * 1000 &&
    supplied.length === expected.length && crypto.timingSafeEqual(Buffer.from(supplied), Buffer.from(expected));
  if (!valid) {
    console.warn('Storage authorization rejected', {
      method: request.method,
      path: request.originalUrl.split('?')[0],
      timestamp,
      ageMs: age,
      suppliedLength: supplied.length,
      expectedLength: expected.length
    });
  }
  return valid;
}

function imageType(buffer) {
  if (!buffer || buffer.length === 0) return undefined;
  if (buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) return 'image/jpeg';
  if (buffer.subarray(0, 4).toString() === 'RIFF' && buffer.subarray(8, 12).toString() === 'WEBP') return 'image/webp';
  return undefined;
}

app.get('/health/live', (_request, response) => response.json({ code: 'OK', data: { status: 'live' } }));
app.use('/internal/storage', (request, response, next) => {
  if (!authorized(request)) {
    response.status(401).json({ code: 'STORAGE_UNAUTHORIZED', message: 'unauthorized' });
    return;
  }
  next();
});
app.post('/internal/storage/images', upload.single('file'), async (request, response, next) => {
  try {
    const type = imageType(request.file?.buffer);
    const extension = imageTypes.get(type);
    if (!extension) {
      response.status(400).json({ code: 'FILE_TYPE_INVALID', message: 'unsupported image' });
      return;
    }
    const now = new Date();
    const objectKey = path.posix.join('posts', String(now.getUTCFullYear()),
      String(now.getUTCMonth() + 1).padStart(2, '0'), crypto.randomUUID() + '.' + extension);
    const destination = path.join(root, objectKey);
    await mkdir(path.dirname(destination), { recursive: true });
    await writeFile(destination, request.file.buffer, { flag: 'wx' });
    response.status(201).json({ objectKey, publicUrl: publicBaseUrl + '/uploads/' + objectKey,
      contentType: type, sizeBytes: request.file.size });
  } catch (error) { next(error); }
});
app.delete('/internal/storage/images/*splat', async (request, response, next) => {
  try {
    await rm(path.join(root, request.params.splat), { force: true });
    response.status(204).end();
  } catch (error) { next(error); }
});
app.use('/uploads', express.static(root, { fallthrough: false }));
app.use((error, _request, response, _next) => {
  console.error(error);
  response.status(500).json({ code: 'STORAGE_INTERNAL_ERROR', message: 'storage error' });
});
app.listen(port, '0.0.0.0', () => console.log('Image storage listening on ' + port));
