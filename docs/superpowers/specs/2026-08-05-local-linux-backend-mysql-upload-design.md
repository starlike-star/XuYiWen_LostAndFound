# 本地 Linux 后端、MySQL 与图片上传联调设计

## 目标

将校园失物招领应用从客户端 Mock/Preferences 模式迁移为可在本地 Linux 环境联调的端云架构。第一阶段只交付“用户登录 → 带图发布 → 列表/详情查看 → 认领或线索提交 → 发布者确认归还”的核心闭环。HarmonyOS 客户端通过 HTTPS API 访问 Spring Boot 后端；后端使用 MySQL 保存业务数据、服务器本地文件系统保存上传图片。存储抽象保持对象键与 URL 分离，后续可切换至华为云 ECS + OBS 而不改变客户端 API 或业务表结构。

## 范围

- 新增 Spring Boot 3 / Java 21 后端、MySQL 8 数据库迁移、Docker Compose 与 Nginx 配置。
- 新增账号密码登录、帖子发布、图片上传、列表、详情、认领、线索和确认归还接口。
- 新增客户端图片选择、预览、压缩/校验、上传进度、删除、失败重试与发布关联。
- 保留当前 ArkUI 页面、领域术语、业务状态与 Repository 架构边界；一期只接入核心页面。

不在第一阶段范围内：邮箱验证码、手机验证码、refresh token、管理员后台、通知系统、收藏、点赞、评论、复杂审核、真实短信/邮件供应商、云 OBS、正式 HTTPS 证书、应用商店发布、内容审核服务、推送服务和多地域部署。

## 架构

```text
HarmonyOS ArkTS client
  └─ HTTPS JSON / multipart
       └─ Nginx
            └─ Spring Boot API
                 ├─ MySQL 8
                 └─ local volume: storage/uploads/
```

后端模块按 `auth`、`post`、`claim`、`file` 分层。客户端新增统一 API Client 与 Repository，Store 仅负责响应式状态和调用编排。客户端不得直连 MySQL。

## 数据库与迁移

Flyway 负责后端运行时迁移，同时仓库提供可单独建库的 SQL 文件：

- `database/01_schema.sql`：创建数据库、表、索引、外键、字符集和约束，不包含演示数据。
- `database/02_seed_dev.sql`：仅开发环境导入演示账号、帖子、图片、认领和线索。

一期核心表：`users`、`user_credentials`、`sessions`、`posts`、`post_images`、`claims`、`clues`。`comments`、`post_likes`、`favorites`、`notifications`、`audit_logs`、`verification_codes` 保留为二期扩展，不在一期建表或实现。

手机号、邮箱、昵称、学号/工号分别建立唯一索引。账号采用状态删除而非物理删除。认领提交和确认归还使用事务或条件更新，避免重复状态转换。

一期认领采用最小状态流：B 对招领帖提交 `PENDING` 认领申请，A 在本人帖子详情中直接执行“确认归还”，后端将该申请更新为 `COMPLETED` 并将帖子更新为 `RESOLVED`。不实现同意、拒绝、多申请比较或管理员介入。B 也可以为寻物帖提交线索；线索只向帖子发布者展示，不改变帖子状态。

## 认证与授权

- 密码只在后端用 Argon2id 或 BCrypt 哈希。
- 一期只签发短期 access token，不实现 refresh token；令牌过期后要求重新登录。
- 一期只支持账号密码登录，不实现手机或邮箱验证码。
- 帖子所有者、认领提交者和归还确认操作全部由服务端基于令牌身份授权，不相信客户端传入的用户 ID 或角色。

## 图片上传与存储抽象

客户端从相册选择图片，先校验类型和大小、生成预览，再通过 `POST /api/v1/files/images` 以 `multipart/form-data` 上传。服务端校验文件魔数、允许类型、大小与数量，使用随机 UUID 生成对象键：

```text
posts/2026/08/<uuid>.webp
```

文件实际写入 `storage/uploads/` 挂载卷；数据库 `post_images.object_key` 保存对象键，`post_images.public_url` 保存访问 URL。`StorageService` 暴露保存、删除、生成 URL 三个操作，本地实现为文件系统，后续 OBS 实现使用同一接口。

帖子发布 API 接收已上传图片 ID 列表并在事务内建立关联；无归属的临时上传记录在定时任务中清理。客户端展示上传进度，失败后允许重试或删除本地选择项。

## API 契约

- `POST /api/v1/auth/login/password`
- `POST /api/v1/files/images`
- `DELETE /api/v1/files/images/{id}`
- `GET /api/v1/posts`
- `POST /api/v1/posts`
- `GET /api/v1/posts/{id}`
- `GET /api/v1/posts/{id}/claims`（仅帖子发布者）
- `GET /api/v1/posts/{id}/clues`（仅帖子发布者）
- `POST /api/v1/posts/{id}/claims`
- `POST /api/v1/posts/{id}/clues`
- `PATCH /api/v1/claims/{id}/return`

统一 JSON 响应包含 `code`、`message`、`data`、`requestId`。时间使用 UTC ISO 8601，分页返回 `items`、`page`、`pageSize`、`total`。

## Linux 部署

`deploy/compose.yaml` 启动 MySQL、API、Nginx；`storage/uploads` 使用 Docker volume。`.env.example` 只提供变量名，生产密码、JWT 密钥、TLS 证书通过环境或 Secret 管理器注入。Nginx 提供反向代理、静态图片访问、请求体限制与健康检查转发。

部署顺序：准备最低权限数据库用户 → 配置 Secret → 启动 MySQL → 执行 Flyway/SQL 迁移 → 启动 API → 检查 `/health/live` 和 `/health/ready` → 启动 Nginx → 将客户端测试基础地址指向 API。

## 客户端改造

- 在 `module.json5` 声明网络和相册所需权限，并在运行时按需要请求。
- 新增 `ApiClient`、`AuthApiRepository`、`ContentApiRepository`、`FileApiRepository`。
- `AuthStore` 改为密码登录 API 调用；`AppStore` 的列表、发布、详情、认领、线索和归还改为异步 API 调用。
- 移除账号全量本地持久化和按账号内容快照保存；Preferences 仅留界面缓存，access token 使用安全存储。
- 发布页增加图片选择、预览、上传和删除，帖子详情按后端返回 URL 加载图片。

## 测试与验收

- 空 MySQL 实例执行迁移成功；重复执行不破坏已有数据。
- 后端覆盖密码登录、帖子归属、认领/线索提交、确认归还、上传类型/大小限制和未归属文件清理。
- 客户端覆盖 API 错误、令牌过期重新登录、上传失败和页面即时刷新。
- Linux 联调通过 A 发布带图帖子 → B 查看列表和详情 → B 提交认领或线索 → A 确认归还，并拒绝越权操作。
- 通过 ArkTS 编译、后端测试、迁移测试及真机/模拟器手工回归。

## 安全与迁移限制

- 不提交 `.env`、数据库口令、JWT 私钥、证书、真实短信/邮件密钥。
- 开发 seed 数据不允许导入生产。
- API 通过 HTTPS 传输；上传文件不使用原始文件名；日志脱敏密码、令牌和身份信息。
- 迁移至 OBS 时只替换 `StorageService` 实现和部署变量，保留对象键、表结构与 API 响应字段。
