import { mkdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { StorageService } from './storage.service.js';

const EXTENSIONS = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };

export class LocalStorageService extends StorageService {
  constructor(root, publicPrefix = '/uploads') {
    super();
    this.root = root;
    this.publicPrefix = publicPrefix;
  }

  async save(buffer, contentType) {
    const extension = EXTENSIONS[contentType];
    if (!extension) throw new Error('unsupported image content type');
    const now = new Date();
    const objectKey = path.posix.join('posts', String(now.getUTCFullYear()),
      String(now.getUTCMonth() + 1).padStart(2, '0'), `${randomUUID()}.${extension}`);
    const destination = path.join(this.root, objectKey);
    await mkdir(path.dirname(destination), { recursive: true });
    await writeFile(destination, buffer, { flag: 'wx' });
    return { objectKey, publicUrl: this.publicUrl(objectKey), sizeBytes: buffer.length };
  }

  async delete(objectKey) {
    await rm(path.join(this.root, objectKey), { force: true });
  }

  publicUrl(objectKey) {
    return `${this.publicPrefix}/${objectKey.split(path.sep).join('/')}`;
  }
}
