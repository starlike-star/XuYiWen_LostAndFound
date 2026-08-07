import { ApiError } from '../common/errors.js';

function sniffImage(buffer) {
  if (buffer.length >= 8 && buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
  if (buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) return 'image/jpeg';
  if (buffer.length >= 12 && buffer.subarray(0, 4).toString() === 'RIFF' && buffer.subarray(8, 12).toString() === 'WEBP') return 'image/webp';
  return undefined;
}

export class FileService {
  constructor(repository, storage) {
    this.repository = repository;
    this.storage = storage;
  }

  async upload(ownerId, file) {
    if (!file?.buffer) throw new ApiError('FILE_REQUIRED', '请选择图片', 400);
    const contentType = sniffImage(file.buffer);
    if (!contentType) throw new ApiError('FILE_TYPE_INVALID', '仅支持 JPEG、PNG、WEBP 图片', 400);
    const stored = await this.storage.save(file.buffer, contentType);
    const image = await this.repository.createTemporary(ownerId, stored, contentType);
    return this.toDto(image);
  }

  async delete(ownerId, imageId) {
    const image = await this.repository.findById(imageId);
    if (!image) throw new ApiError('FILE_NOT_FOUND', '图片不存在', 404);
    if (image.owner_id !== ownerId) throw new ApiError('FORBIDDEN', '无权操作该图片', 403);
    if (image.status !== 'TEMPORARY') throw new ApiError('FILE_ATTACHED', '已关联的图片不能删除', 409);
    await this.storage.delete(image.object_key);
    await this.repository.delete(imageId);
  }

  toDto(image) {
    return { id: image.id, publicUrl: image.public_url, contentType: image.content_type,
      sizeBytes: image.size_bytes, status: image.status };
  }
}
