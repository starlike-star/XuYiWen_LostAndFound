import { ApiError } from '../common/errors.js';

function content(value) { return typeof value === 'string' ? value.trim() : ''; }

export class ClaimService {
  constructor(repository) { this.repository = repository; }

  async createClaim(userId, postId, answerValue) {
    const post = await this.requireActiveForeignPost(userId, postId, 'LOST_NOTICE');
    const answer = content(answerValue);
    if (answer.length < 1 || answer.length > 500) throw new ApiError('CLAIM_INVALID', '认领说明须为 1 至 500 个字符', 400);
    return this.toClaim(await this.repository.createClaim(post.id, userId, answer));
  }

  async createClue(userId, postId, contentValue) {
    const post = await this.requireActiveForeignPost(userId, postId, 'SEARCH_NOTICE');
    const clue = content(contentValue);
    if (clue.length < 1 || clue.length > 500) throw new ApiError('CLUE_INVALID', '线索须为 1 至 500 个字符', 400);
    return this.toClue(await this.repository.createClue(post.id, userId, clue));
  }

  async listClaims(ownerId, postId) {
    await this.requireOwner(ownerId, postId);
    return (await this.repository.listClaims(postId)).map((claim) => this.toClaim(claim));
  }

  async listClues(ownerId, postId) {
    await this.requireOwner(ownerId, postId);
    return (await this.repository.listClues(postId)).map((clue) => this.toClue(clue));
  }

  async confirmReturn(ownerId, claimId) {
    const result = await this.repository.confirmReturn(claimId, ownerId);
    if (result.type === 'NOT_FOUND') throw new ApiError('CLAIM_NOT_FOUND', '认领申请不存在', 404);
    if (result.type === 'FORBIDDEN') throw new ApiError('FORBIDDEN', '无权确认归还', 403);
    if (result.type === 'CONFLICT') throw new ApiError('CLAIM_CONFLICT', '该认领或帖子已处理', 409);
    return { claimId, postId: result.postId, status: 'COMPLETED' };
  }

  async requireActiveForeignPost(userId, postId, kind) {
    const post = await this.repository.findPost(postId);
    if (!post) throw new ApiError('POST_NOT_FOUND', '帖子不存在', 404);
    if (post.owner_id === userId) throw new ApiError('SELF_ACTION_FORBIDDEN', '不能操作自己的帖子', 403);
    if (post.kind !== kind || post.status !== 'ACTIVE') throw new ApiError('POST_NOT_AVAILABLE', '该帖子当前不能执行此操作', 409);
    return post;
  }

  async requireOwner(ownerId, postId) {
    const post = await this.repository.findPost(postId);
    if (!post) throw new ApiError('POST_NOT_FOUND', '帖子不存在', 404);
    if (post.owner_id !== ownerId) throw new ApiError('FORBIDDEN', '无权查看该信息', 403);
  }

  toClaim(row) { return { id: row.id, postId: row.post_id, applicantId: row.applicant_id,
    applicantNickname: row.applicant_nickname, answer: row.answer, status: row.status,
    createdAt: row.created_at, completedAt: row.completed_at }; }
  toClue(row) { return { id: row.id, postId: row.post_id, authorId: row.author_id,
    authorNickname: row.author_nickname, content: row.content, createdAt: row.created_at }; }
}
