# 管理员账号与帖子软删除实施计划

1. 修改数据库脚本和 Knex 核心迁移，将 `posts.status` 扩展为 `DELETED`，加入 bcrypt 管理员种子账号。
2. 在帖子 Repository/Service 中增加管理员列表、软删除和恢复方法，并新增管理员路由及权限测试。
3. 扩展 ArkTS API 类型、客户端和状态模型，确保普通列表过滤 `DELETED` 帖子。
4. 在 `AdminDashboard` 增加帖子管理卡片，接入删除/恢复操作并刷新状态。
5. 执行 Node 测试、Node 语法检查、ArkTS 编译和差异检查；提供 SQL 执行及验收流程。
