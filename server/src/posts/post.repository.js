import { randomUUID } from 'node:crypto';

export class PostRepository {
  constructor(db) { this.db = db; }

  async create(ownerId, draft) {
    return this.db.transaction(async (trx) => {
      const post = {
        id: randomUUID(), owner_id: ownerId, kind: draft.kind, title: draft.title, description: draft.description,
        category: draft.category, location: draft.location, campus: draft.campus, contact: draft.contact, status: 'ACTIVE'
      };
      await trx('posts').insert(post);
      if (draft.imageIds.length > 0) {
        const images = await trx('post_images').whereIn('id', draft.imageIds).forUpdate();
        if (images.length !== draft.imageIds.length ||
          images.some((image) => image.owner_id !== ownerId || image.status !== 'TEMPORARY')) {
          throw Object.assign(new Error('image ownership mismatch'), { code: 'IMAGE_OWNERSHIP' });
        }
        await trx('post_images').whereIn('id', draft.imageIds).update({ status: 'ATTACHED' });
        await trx('post_image_links').insert(draft.imageIds.map((imageId, position) => ({
          post_id: post.id, image_id: imageId, position
        })));
      }
      return post.id;
    });
  }

  async list({ page, pageSize, keyword, kind, status, includeDeleted = false }) {
    const base = this.db('posts as post').join('users as owner', 'owner.id', 'post.owner_id')
      .select('post.*', 'owner.nickname as owner_nickname');
    if (keyword) base.where((q) => q.whereLike('post.title', `%${keyword}%`).orWhereLike('post.description', `%${keyword}%`));
    if (kind) base.where('post.kind', kind);
    if (status) base.where('post.status', status);
    if (!includeDeleted) base.whereNot('post.status', 'DELETED');
    const count = await base.clone().clearSelect().clearOrder().count({ total: '*' }).first();
    const rows = await base.orderBy([{ column: 'post.created_at', order: 'desc' }, { column: 'post.id', order: 'desc' }])
      .limit(pageSize).offset((page - 1) * pageSize);
    if (rows.length > 0) {
      const postIds = rows.map((row) => row.id);
      const [images, commentCounts] = await Promise.all([
        this.db('post_image_links as link')
          .join('post_images as image', 'image.id', 'link.image_id')
          .select('link.post_id', 'image.public_url')
          .whereIn('link.post_id', postIds)
          .orderBy('link.position'),
        this.db('post_comments').select('post_id').count({ count: '*' })
          .whereIn('post_id', postIds).groupBy('post_id')
      ]);
      const firstImageByPost = new Map();
      for (const image of images) {
        if (!firstImageByPost.has(image.post_id)) firstImageByPost.set(image.post_id, image.public_url);
      }
      const commentCountByPost = new Map(commentCounts.map((row) => [row.post_id, Number(row.count)]));
      for (const row of rows) {
        row.image_url = firstImageByPost.get(row.id) ?? '';
        row.comment_count = commentCountByPost.get(row.id) ?? 0;
      }
    }
    return { rows, total: Number(count.total) };
  }

  async listInteractions(postIds, userId = '') {
    const result = new Map();
    if (postIds.length === 0) return result;
    const [likes, favorites] = await Promise.all([
      this.db('post_likes').whereIn('post_id', postIds).select('post_id').count({ count: '*' }).groupBy('post_id'),
      this.db('post_favorites').whereIn('post_id', postIds).select('post_id').count({ count: '*' }).groupBy('post_id')
    ]);
    for (const postId of postIds) {
      result.set(postId, { likeCount: 0, isLiked: false, favoriteCount: 0, isFavorite: false });
    }
    for (const row of likes) result.get(row.post_id).likeCount = Number(row.count);
    for (const row of favorites) result.get(row.post_id).favoriteCount = Number(row.count);
    if (userId) {
      const [userLikes, userFavorites] = await Promise.all([
        this.db('post_likes').whereIn('post_id', postIds).andWhere('user_id', userId).select('post_id'),
        this.db('post_favorites').whereIn('post_id', postIds).andWhere('user_id', userId).select('post_id')
      ]);
      for (const row of userLikes) result.get(row.post_id).isLiked = true;
      for (const row of userFavorites) result.get(row.post_id).isFavorite = true;
    }
    return result;
  }

  async getInteractions(postId, userId = '') {
    const [likeCount, favoriteCount, liked, favorited] = await Promise.all([
      this.db('post_likes').where({ post_id: postId }).count({ count: '*' }).first(),
      this.db('post_favorites').where({ post_id: postId }).count({ count: '*' }).first(),
      userId ? this.db('post_likes').where({ post_id: postId, user_id: userId }).first('post_id') : undefined,
      userId ? this.db('post_favorites').where({ post_id: postId, user_id: userId }).first('post_id') : undefined
    ]);
    return {
      likeCount: Number(likeCount?.count ?? 0),
      isLiked: Boolean(liked),
      favoriteCount: Number(favoriteCount?.count ?? 0),
      isFavorite: Boolean(favorited)
    };
  }

  async setInteraction(table, postId, userId, enabled) {
    const post = await this.db('posts').where({ id: postId }).first('id');
    if (!post) return undefined;
    if (enabled) {
      await this.db(table).insert({ post_id: postId, user_id: userId }).onConflict(['post_id', 'user_id']).ignore();
    } else {
      await this.db(table).where({ post_id: postId, user_id: userId }).delete();
    }
    return this.getInteractions(postId, userId);
  }

  async findDetail(id) {
    const post = await this.db('posts as post').join('users as owner', 'owner.id', 'post.owner_id')
      .select('post.*', 'owner.nickname as owner_nickname', 'owner.department as owner_department')
      .where('post.id', id).first();
    if (!post) return undefined;
    post.images = await this.db('post_image_links as link').join('post_images as image', 'image.id', 'link.image_id')
      .select('image.id', 'image.public_url', 'image.content_type', 'image.size_bytes')
      .where('link.post_id', id).orderBy('link.position');
    const commentCount = await this.db('post_comments').where({ post_id: id }).count({ count: '*' }).first();
    post.comment_count = Number(commentCount?.count ?? 0);
    return post;
  }

  async updateStatus(id, status) {
    const post = await this.db('posts').where({ id }).first('id');
    if (!post) return undefined;
    await this.db('posts').where({ id }).update({ status });
    return this.findDetail(id);
  }
}
