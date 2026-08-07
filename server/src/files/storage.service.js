export class StorageService {
  async save(_buffer, _contentType) {
    throw new Error('StorageService.save must be implemented');
  }

  async delete(_objectKey) {
    throw new Error('StorageService.delete must be implemented');
  }

  publicUrl(_objectKey) {
    throw new Error('StorageService.publicUrl must be implemented');
  }
}
