# Node.js 一期核心后端、MySQL 与图片上传设计

## 目标

将校园失物招领应用从客户端 Mock/Preferences 模式迁移为可在本地 Linux 环境联调的端云架构。第一阶段只交付「密码登录 → 带图发布 → 列表和详情 → 认领或线索 → 发布者确认归还」闭环。

HarmonyOS ArkTS 客户端通过 HTTPS JSON 与 multipart API 访问 Node.js 服务；MySQL 8 保存业务数据；服务器本地文件系统保存图片。图片以对象键与公开 URL 表达，后续切换到华为云 ECS + OBS 时不改变客户端 API 或业务表结构。

## 范围

实现：

- Node.js 22、Express 5、纯 JavaScript 后端。
- MySQL 8、Knex 迁移与可单独建库的 SQL 脚本。
- 密码登录、短期 JWT access token、服务端所有权校验。
- 图片上传、列表、详情、发布、认领、线索、确认归还。
- Docker Compose、Nginx、服务器本地图片存储。
- 客户端的网络请求、图片选择和核心页面数据改造。

本期不实现：

- 手机或邮箱验证码、refresh token、管理员后台、通知、收藏、点赞、评论、复杂审核。
- OBS 实现、真实 TLS 证书、应用商店发布、短信/邮件供应商。

## 架构

```text
HarmonyOS ArkTS client
  └─ HTTPS JSON / multipart
       └─ Nginx
            └─ Express API (Node.js 22)
                 ├─ Repository interfaces ─ MySQL 8
                 └─ StorageService ─ local volume: storage/uploads/
```

服务端按 `auth`、`files`、`posts`、`claims` 模块组织。每个模块由路由、服务和 Repository 构成：路由只处理 HTTP，服务包含业务规则，Repository 只执行数据库访问。StorageService 仅暴露保存、删除、生成 URL 的对象存储接口；LocalStorageService 是一期实现，OBSStorageService 可在后续替换。

## 依赖与安全边界

- 运行时：Node.js 22、Express 5、mysql2、Knex、jsonwebtoken、bcrypt、Multer。
- 测试：Node 内置 test runner、supertest；数据库集成测试只从环境变量读取连接信息。
- 密码使用 bcrypt 哈希；服务端绝不沿用客户端 Mock 的摘要算法。
- Token 只含用户 ID 与角色，15 分钟有效；不实现 refresh token。
- 客户端不直接连接 MySQL，不传入可被信任的用户 ID 或角色。
- 真实密码、JWT 密钥、证书和数据库凭据只经环境变量或容器 Secret 注入，不提交到仓库。

## 数据库与迁移

Knex 迁移是服务启动/部署的唯一迁移机制；同时提供供人工建库的 SQL：

- `database/01_schema.sql`：仅创建数据库、表、索引与约束。
- `database/02_seed_dev.sql`：仅开发演示数据，绝不作为生产启动步骤。

一期表为 `users`、`user_credentials`、`sessions`、`posts`、`post_images`、`claims`、`clues`。手机号、邮箱、昵称、学号/工号分别唯一；账号使用状态删除而非物理删除。

每次创建帖子时，在一个事务中确认所有临时图片都归当前用户所有，并将其标为已关联。确认归还使用条件更新，避免重复完成。临时图片记录由显式清理任务按过期时间删除，不能影响已经关联的图片。

## 图片上传和对象存储接口

`POST /api/v1/files/images` 接收 multipart 字段 `file`。服务器限制 JPEG、PNG、WEBP，验证魔数，单文件最多 10 MiB；使用 UUID 产生路径 `posts/YYYY/MM/<uuid>.<ext>`。数据库保存 `object_key`、`public_url`、类型、大小、所有者和 `TEMPORARY/ATTACHED` 状态，绝不保存客户端路径或原始文件名。

`StorageService.save(buffer, contentType)` 返回 `{ objectKey, publicUrl, sizeBytes }`，`delete(objectKey)` 删除对象，`publicUrl(objectKey)` 生成可访问 URL。LocalStorageService 写入 Docker 挂载卷；未来 OBS 实现保持同一接口。

## API 契约

- `POST /api/v1/auth/login/password`
- `POST /api/v1/files/images`
- `DELETE /api/v1/files/images/{id}`
- `GET /api/v1/posts`
- `POST /api/v1/posts`
- `GET /api/v1/posts/{id}`
- `GET /api/v1/posts/{id}/claims`（仅发布者）
- `GET /api/v1/posts/{id}/clues`（仅发布者）
- `POST /api/v1/posts/{id}/claims`
- `POST /api/v1/posts/{id}/clues`
- `PATCH /api/v1/claims/{id}/return`
- `GET /health/live`、`GET /health/ready`

统一响应：`{ code, message, data, requestId }`。时间为 UTC ISO 8601；分页返回 `items`、`page`、`pageSize`、`total`。受保护接口使用 `Authorization: Bearer <token>`。

认领只适用于 `LOST_NOTICE`，线索只适用于 `SEARCH_NOTICE`。申请者不得操作自己的帖子。认领从 `PENDING` 到 `COMPLETED` 时，帖子从 `ACTIVE` 到 `RESOLVED`；不提供同意、拒绝或多申请比较。

## 客户端改造

保留 ArkUI 页面与既有 Repository 边界，新增 ApiClient、AuthApiRepository、ContentApiRepository、FileApiRepository 及图片选择服务。图片选择使用官方 `PhotoViewPicker`，只授权用户主动选择的图片。发布先上传图片，再用返回的图片 ID 创建帖子；列表和详情直接使用服务器 URL。

一期核心页面切换到异步 API 后，AuthStore 和 AppStore 用服务端返回值更新状态。401 时清除本地 access token 并回到未登录状态。Mock/Preferences 的账号和内容快照只在调用方全部迁移后移除；本期暂缓的功能不可部分接入 Mock。

## Linux 部署

`deploy/compose.yaml` 启动 mysql、api、nginx；主机仅暴露 Nginx 的 8080 端口。图片卷挂载为 `lostfound_uploads`；Nginx 反向代理 API 并只读暴露 `/uploads/`。环境模板只提供变量名，不含可用机密。

部署顺序：配置机密 → 启动 MySQL → 执行 Knex 迁移 → 启动 API → 检查 health → 启动/检查 Nginx → 配置客户端 API 基址。回滚依赖部署前的 MySQL 备份和图片卷备份，不执行自动删库或删卷。

## 验收与测试

- Knex 迁移可在空 MySQL 实例创建七张核心表，重复手机号被唯一约束拒绝。
- 后端覆盖密码登录、鉴权、图片类型/大小/所有权、帖子图片归属、认领/线索、确认归还及越权拒绝。
- ArkTS 测试覆盖 API 错误、401 退出、服务端状态即时刷新。
- Linux 联调验证：A 上传图片并发布，B 看见列表和详情后提交认领或线索，A 确认归还；越权请求失败。
- 未连接设备时，不宣称已验证图片选择器的真机体验。
