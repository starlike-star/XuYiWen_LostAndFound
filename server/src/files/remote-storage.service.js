import crypto from 'node:crypto';
import { StorageService } from './storage.service.js';
import { ApiError } from '../common/errors.js';

export class RemoteStorageService extends StorageService {
  constructor(baseUrl, sharedSecret, publicBaseUrl) {
    super();
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.sharedSecret = sharedSecret;
    this.publicBaseUrl = publicBaseUrl.replace(/\/$/, '');
  }

  headers(method, requestPath) {
    const timestamp = String(Date.now());
    const signature = crypto.createHmac('sha256', this.sharedSecret)
      .update(timestamp + ':' + method + ':' + requestPath).digest('hex');
    return { 'X-Storage-Timestamp': timestamp, 'X-Storage-Signature': signature };
  }

  async save(buffer, contentType) {
    const requestPath = '/internal/storage/images';
    const form = new FormData();
    form.append('file', new Blob([buffer], { type: contentType }), 'upload');
    const authHeaders = this.headers('POST', requestPath);
    const response = await fetch(this.baseUrl + requestPath, {
      method: 'POST', headers: authHeaders, body: form
    });
    if (!response.ok) {
      const detail = await response.text().catch(() => '');
      console.error('Remote image storage upload rejected', {
        status: response.status,
        detail: detail.slice(0, 500),
        requestPath,
        timestamp: authHeaders['X-Storage-Timestamp'],
        signatureLength: authHeaders['X-Storage-Signature'].length
      });
      throw new ApiError('STORAGE_UPLOAD_FAILED',
        `图片存储服务返回 HTTP ${response.status}${detail ? `: ${detail.slice(0, 180)}` : ''}`, 502);
    }
    const result = await response.json();
    return { objectKey: result.objectKey, publicUrl: this.publicUrl(result.objectKey),
      sizeBytes: result.sizeBytes };
  }

  async delete(objectKey) {
    const requestPath = '/internal/storage/images/' + objectKey;
    const response = await fetch(this.baseUrl + requestPath, {
      method: 'DELETE', headers: this.headers('DELETE', requestPath)
    });
    if (!response.ok && response.status !== 404) throw new Error('remote image storage delete failed');
  }

  publicUrl(objectKey) {
    return this.publicBaseUrl + '/uploads/' + objectKey;
  }

  async fetchObject(objectKey) {
    const requestPath = '/uploads/' + objectKey;
    return fetch(this.baseUrl + requestPath, {
      method: 'GET', headers: this.headers('GET', requestPath)
    });
  }
}
