import { randomUUID } from 'node:crypto';

export class FileRepository {
  constructor(db) {
    this.db = db;
  }

  async createTemporary(ownerId, stored, contentType) {
    const row = {
      id: randomUUID(), owner_id: ownerId, object_key: stored.objectKey, public_url: stored.publicUrl,
      content_type: contentType, size_bytes: stored.sizeBytes, status: 'TEMPORARY'
    };
    await this.db('post_images').insert(row);
    return this.findById(row.id);
  }

  findById(id) {
    return this.db('post_images').where({ id }).first();
  }

  async delete(id) {
    await this.db('post_images').where({ id }).delete();
  }
}
