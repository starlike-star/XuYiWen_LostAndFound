import { randomUUID } from 'node:crypto';

export class ClaimRepository {
  constructor(db) { this.db = db; }

  findPost(id) { return this.db('posts').where({ id }).first(); }

  async createClaim(postId, applicantId, answer) {
    const row = { id: randomUUID(), post_id: postId, applicant_id: applicantId, answer, status: 'PENDING' };
    await this.db('claims').insert(row);
    return this.db('claims').where({ id: row.id }).first();
  }

  async createClue(postId, authorId, content) {
    const row = { id: randomUUID(), post_id: postId, author_id: authorId, content };
    await this.db('clues').insert(row);
    return this.db('clues').where({ id: row.id }).first();
  }

  listClaims(postId) {
    return this.db('claims as claim').join('users as u', 'u.id', 'claim.applicant_id')
      .select('claim.*', 'u.nickname as applicant_nickname').where('claim.post_id', postId)
      .orderBy('claim.created_at', 'desc');
  }

  listClues(postId) {
    return this.db('clues as clue').join('users as u', 'u.id', 'clue.author_id')
      .select('clue.*', 'u.nickname as author_nickname').where('clue.post_id', postId)
      .orderBy('clue.created_at', 'desc');
  }

  async confirmReturn(claimId, ownerId) {
    return this.db.transaction(async (trx) => {
      const claim = await trx('claims as claim').join('posts as post', 'post.id', 'claim.post_id')
        .select('claim.id', 'claim.post_id', 'claim.status as claim_status', 'post.owner_id', 'post.status as post_status')
        .where('claim.id', claimId).forUpdate().first();
      if (!claim) return { type: 'NOT_FOUND' };
      if (claim.owner_id !== ownerId) return { type: 'FORBIDDEN' };
      if (claim.claim_status !== 'PENDING' || claim.post_status !== 'ACTIVE') return { type: 'CONFLICT' };
      await trx('claims').where({ id: claimId, status: 'PENDING' }).update({ status: 'COMPLETED', completed_at: trx.fn.now() });
      await trx('posts').where({ id: claim.post_id, status: 'ACTIVE' }).update({ status: 'RESOLVED', resolved_at: trx.fn.now() });
      return { type: 'OK', postId: claim.post_id };
    });
  }
}
