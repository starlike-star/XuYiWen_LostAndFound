export class AuthRepository {
  constructor(db) {
    this.db = db;
  }

  async findByAccount(account) {
    const normalized = account.includes('@') ? account.toLowerCase() : account;
    return this.db('user_credentials as credential')
      .join('users as u', 'u.id', 'credential.user_id')
      .select('u.id', 'u.nickname', 'u.identity_role', 'u.status', 'u.email',
        'u.phone', 'u.department', 'u.campus', 'u.is_admin', 'credential.password_hash')
      .where((query) => query.where('u.phone', normalized).orWhere('u.email', normalized))
      .first();
  }
}
