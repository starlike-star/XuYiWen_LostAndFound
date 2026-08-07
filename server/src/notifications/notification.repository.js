export class NotificationRepository {
  constructor(db) {
    this.db = db;
  }

  async list(userId) {
    const [receivedClaims, receivedClues, submittedClaims, submittedClues] = await Promise.all([
      this.db('claims as claim')
        .join('posts as post', 'post.id', 'claim.post_id')
        .select(
          'claim.id as sourceId',
          this.db.raw("'CLAIM_RECEIVED' as type"),
          'claim.answer as content',
          'claim.post_id as postId',
          'claim.created_at as createdAt'
        )
        .where('post.owner_id', userId),
      this.db('clues as clue')
        .join('posts as post', 'post.id', 'clue.post_id')
        .select(
          'clue.id as sourceId',
          this.db.raw("'CLUE_RECEIVED' as type"),
          'clue.content',
          'clue.post_id as postId',
          'clue.created_at as createdAt'
        )
        .where('post.owner_id', userId),
      this.db('claims as claim')
        .select(
          'claim.id as sourceId',
          this.db.raw("'CLAIM_STATUS' as type"),
          'claim.status as content',
          'claim.post_id as postId',
          'claim.updated_at as createdAt'
        )
        .where('claim.applicant_id', userId),
      this.db('clues as clue')
        .select(
          'clue.id as sourceId',
          this.db.raw("'CLUE_SUBMITTED' as type"),
          'clue.content',
          'clue.post_id as postId',
          'clue.created_at as createdAt'
        )
        .where('clue.author_id', userId)
    ]);
    return [...receivedClaims, ...receivedClues, ...submittedClaims, ...submittedClues];
  }

  async listReadIds(userId) {
    const rows = await this.db('notification_reads').where({ user_id: userId }).select('notification_id');
    return rows.map((row) => row.notification_id);
  }

  async markRead(userId, notificationIds) {
    if (notificationIds.length === 0) return;
    await this.db('notification_reads').insert(notificationIds.map((notificationId) => ({
      user_id: userId, notification_id: notificationId
    }))).onConflict(['user_id', 'notification_id']).merge({ read_at: this.db.fn.now() });
  }
}
