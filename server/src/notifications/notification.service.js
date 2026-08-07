const TITLES = {
  CLAIM_RECEIVED: '收到认领申请',
  CLUE_RECEIVED: '收到新线索',
  CLAIM_STATUS: '认领申请状态',
  CLUE_SUBMITTED: '线索已提交'
};

function notificationId(type, sourceId) {
  return `${type.toLowerCase().replaceAll('_', '-')}-${sourceId}`;
}

export class NotificationService {
  constructor(repository) {
    this.repository = repository;
  }

  async list(userId) {
    const rows = await this.repository.list(userId);
    const readIds = this.repository.listReadIds ? new Set(await this.repository.listReadIds(userId)) : new Set();
    const items = rows.map((row) => ({
      id: notificationId(row.type, row.sourceId),
      type: row.type,
      title: TITLES[row.type] ?? '系统消息',
      content: row.content,
      postId: row.postId,
      createdAt: row.createdAt,
      read: readIds.has(notificationId(row.type, row.sourceId))
    }));
    items.sort((left, right) => new Date(right.createdAt).getTime() - new Date(left.createdAt).getTime());
    return { items, total: items.length };
  }

  async markRead(userId, notificationIds) {
    const ids = Array.isArray(notificationIds) ? notificationIds
      .filter((id) => typeof id === 'string' && id.trim().length > 0).slice(0, 500) : [];
    if (this.repository.markRead) await this.repository.markRead(userId, ids);
    return { count: ids.length };
  }
}
