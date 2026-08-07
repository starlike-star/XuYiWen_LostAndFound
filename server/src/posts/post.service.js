import { ApiError } from '../common/errors.js';

const KINDS = new Set(['LOST_NOTICE', 'SEARCH_NOTICE']);

function clean(value) { return typeof value === 'string' ? value.trim() : ''; }

export class PostService {
  constructor(repository) { this.repository = repository; }

  async create(ownerId, input) {
    const draft = {
      kind: input?.kind, title: clean(input?.title), description: clean(input?.description),
      category: clean(input?.category), location: clean(input?.location), campus: clean(input?.campus),
      contact: clean(input?.contact), imageIds: Array.isArray(input?.imageIds) ? input.imageIds : []
    };
    if (!KINDS.has(draft.kind) || draft.title.length < 1 || draft.title.length > 80 ||
      draft.description.length < 1 || draft.description.length > 2000 ||
      !draft.category || !draft.location || !draft.campus || !draft.contact || draft.imageIds.length > 6) {
      throw new ApiError('POST_INVALID', 'post payload is invalid', 400);
    }
    try {
      const postId = await this.repository.create(ownerId, draft);
      const post = await this.repository.findDetail(postId);
      return this.toDetail(post, await this.repository.getInteractions(postId, ownerId));
    } catch (error) {
      if (error.code === 'IMAGE_OWNERSHIP') {
        throw new ApiError('IMAGE_OWNERSHIP', 'image does not exist or is not owned by the user', 403);
      }
      throw error;
    }
  }

  async list(query, userId = '', includeDeleted = false) {
    const page = Math.max(1, Number(query.page) || 1);
    const pageSize = Math.min(50, Math.max(1, Number(query.pageSize) || 20));
    const result = await this.repository.list({ page, pageSize, keyword: clean(query.keyword), kind: query.kind, status: query.status, includeDeleted });
    const interactions = await this.repository.listInteractions(result.rows.map((row) => row.id), userId);
    return { items: result.rows.map((row) => this.toSummary(row, interactions.get(row.id))), page, pageSize, total: result.total };
  }

  async detail(id, userId = '') {
    const post = await this.repository.findDetail(id);
    if (!post) throw new ApiError('POST_NOT_FOUND', 'post not found', 404);
    return this.toDetail(post, await this.repository.getInteractions(id, userId));
  }

  async setLike(postId, userId, enabled) {
    const interactions = await this.repository.setInteraction('post_likes', postId, userId, enabled);
    if (!interactions) throw new ApiError('POST_NOT_FOUND', 'post not found', 404);
    return { postId, ...interactions };
  }

  async setFavorite(postId, userId, enabled) {
    const interactions = await this.repository.setInteraction('post_favorites', postId, userId, enabled);
    if (!interactions) throw new ApiError('POST_NOT_FOUND', 'post not found', 404);
    return { postId, ...interactions };
  }

  async setAdminStatus(postId, status) {
    const post = await this.repository.updateStatus(postId, status);
    if (!post) throw new ApiError('POST_NOT_FOUND', 'post not found', 404);
    return this.toDetail(post, await this.repository.getInteractions(postId));
  }

  toSummary(post, interactions = {}) {
    return { id: post.id, ownerId: post.owner_id, ownerNickname: post.owner_nickname, kind: post.kind,
      title: post.title, category: post.category, location: post.location, campus: post.campus, status: post.status,
      description: post.description, imageUrl: post.image_url ?? '', likeCount: interactions.likeCount ?? 0,
      isLiked: interactions.isLiked ?? false, favoriteCount: interactions.favoriteCount ?? 0,
      isFavorite: interactions.isFavorite ?? false, commentCount: Number(post.comment_count ?? 0), createdAt: post.created_at };
  }

  toDetail(post, interactions = {}) {
    return { ...this.toSummary(post, interactions), description: post.description, contact: post.contact,
      ownerDepartment: post.owner_department, images: (post.images ?? []).map((image) => ({
        id: image.id, publicUrl: image.public_url, contentType: image.content_type, sizeBytes: image.size_bytes
      })) };
  }
}
