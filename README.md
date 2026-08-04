# 校园失物招领

面向高校师生的 HarmonyOS 校园失物招领客户端演示项目。应用围绕“发布—查找—互动—认领/线索—归还”构建业务闭环，并按照产品需求实现普通用户账号体系和管理员用户管理。

当前版本是纯客户端 MVP：账号、会话以及每个账号独立的失物动态、评论、消息、认领和收藏记录均使用 Preferences 保存在本地，不依赖真实后端、短信、邮件、地图或推送服务。本 README 同时给出数据库版的目标架构和部署契约；除非仓库中出现后端工程、数据库迁移和 API 配置，否则不能将当前版本描述为“已连接数据库”。

## 交付状态

| 能力 | 当前状态 | 数据库版交付要求 |
| --- | --- | --- |
| HarmonyOS 客户端 UI | 已实现 | 保持页面与响应式 Store 结构 |
| 本地账号与会话 | 已实现（Preferences） | 替换为服务端认证与安全 Token |
| 业务数据持久化 | 已实现（账号级快照） | 替换为资源级 REST API 与数据库事务 |
| 手机号/邮箱验证码登录 | 已实现演示流程 | 接入短信、邮件服务并服务端限流 |
| 图片 | Emoji/色块占位 | 对象存储上传和 HTTPS URL |
| 后端、数据库、迁移 | 未提供 | 必须新增后才能部署数据库版 |
| 自动化测试 | 26 项本地单元测试 | 增加 API、数据库迁移和端到端测试 |
| 设备验收 | 未完成 | 模拟器与真机执行 `TESTING.md` |

## 技术环境

| 项目 | 配置 |
| --- | --- |
| 操作系统 | HarmonyOS |
| 开发语言 | ArkTS |
| UI 框架 | ArkUI |
| API 版本 | HarmonyOS 6.1.1 / API 24 |
| 工程模型 | Stage 模型、单 EntryAbility |
| 本地存储 | Preferences |
| 测试框架 | Hypium 1.0.25 |

建议使用与工程 SDK 版本匹配的 DevEco Studio 打开和运行项目。

## 功能概览

### 普通用户

- 手机号注册和学校邮箱注册。
- 学生、教师、教职工三类身份认证。
- 手机号或学校邮箱密码登录，手机号或学校邮箱验证码登录。
- 动态六位演示验证码、五分钟有效期和六十秒重发限制。
- 七天本地免登录会话和单活动 Token 模拟。
- 手机验证码找回密码。
- 编辑昵称、院系/部门、年级、联系方式和校区。
- 修改密码、换绑手机号、换绑学校邮箱、退出和注销账号。
- 存在未完结动态时禁止注销。

### 失物招领

- 失物、寻物信息流及关键词、类型、分类和状态筛选。
- 发布失物或寻物信息。
- 动态详情、点赞、收藏和评论。
- 失物认领、防冒领特征说明和发布者审核。
- 寻物线索提交。
- 认领同意、拒绝和确认归还。
- 消息通知、我的发布、认领/线索和收藏记录。

界面中的“失物”表示拾到物品后发布的招领信息；“寻物”表示失主发布的寻找信息。代码中分别使用 `LOST_NOTICE` 和 `SEARCH_NOTICE`，避免 `lost/found` 语义混淆。

### 管理员

- 使用统一登录页进入独立管理员工作台。
- 按身份、院系/部门和账号状态筛选用户。
- 查看认证资料、发布记录、违规记录和管理审计记录。
- 冻结、解冻和强制注销账号。
- 提升或取消管理员权限，同时保留用户原始身份角色。
- 高影响操作需要二次确认，管理员不能冻结、注销或降级自己。

本期不包含信息审核、举报处理、数据统计和系统配置。

## 演示账号

| 类型 | 账号 | 密码 |
| --- | --- | --- |
| 学生 | `13800000001` 或 `lin@campus.edu.cn` | `Campus123` |
| 管理员 | `admin@campus.edu.cn` | `Admin1234` |

验证码不会发送到真实手机或邮箱。点击“获取演示验证码”后，六位验证码会直接显示在页面中。

首次启动会创建预置账号。账号修改、注册结果和登录会话保存在本地；如需恢复预置账号，可在系统设置中清除该应用的数据。

## 运行项目

### DevEco Studio

1. 使用 DevEco Studio 打开项目根目录。
2. 等待 Hvigor 同步完成。
3. 确认本地已安装 HarmonyOS 6.1.1 / API 24 SDK。
4. 选择 `entry` 模块和 `default` 产品。
5. 连接模拟器或真机后运行应用。

项目没有配置签名信息。需要安装到真机时，请在 DevEco Studio 中配置自己的调试签名，不要将签名文件或私钥提交到项目中。

### 命令行编译检查

在 Windows PowerShell 中执行：

```powershell
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
$env:Path = 'C:\Program Files\Huawei\DevEco Studio\tools\node;' + $env:Path
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --mode module `
  -p product=default `
  -p module=entry@default `
  -p buildMode=debug `
  'default@CompileArkTS' `
  --no-daemon `
  --no-incremental
```

该命令只执行 ArkTS 和资源编译检查，不生成发布安装包。

## 运行单元测试

```powershell
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
$env:Path = 'C:\Program Files\Huawei\DevEco Studio\tools\node;' + $env:Path
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --mode module `
  -p product=default `
  -p module=entry@default `
  -p buildMode=debug `
  test `
  --no-daemon `
  --no-incremental
```

主要测试文件：

- `entry/src/test/AccountRules.test.ets`：密码、邮箱、昵称、身份字段、重复注册、登录和管理员冻结规则。
- `entry/src/test/AppStore.test.ets`：发布、点赞、收藏、认领审核和归还状态流。
- `entry/src/test/ContentCodec.test.ets`：超过 Preferences 单值上限的大快照分片与无损合并。

完整的自动化与真机/模拟器手工回归步骤见 [TESTING.md](TESTING.md)。

## 项目结构

```text
LostAndFound/
├─ AppScope/                         # 应用级配置和资源
├─ entry/
│  └─ src/
│     ├─ main/
│     │  ├─ ets/
│     │  │  ├─ models/              # 账号与失物招领领域模型
│     │  │  ├─ services/            # 校验、持久化和 Mock 鉴权服务
│     │  │  ├─ stores/              # AuthStore 与 AppStore
│     │  │  ├─ pages/Index.ets      # 启动鉴权、用户端和管理员端 UI
│     │  │  └─ entryability/        # EntryAbility
│     │  └─ resources/              # 模块资源
│     └─ test/                       # Hypium 本地单元测试
├─ build-profile.json5              # API 24 产品配置
└─ oh-package.json5                 # 项目依赖声明
```

## 数据与状态规则

- `AccountRepository` 和 `ContentRepository` 分别负责账号数据与账号级内容快照的 Preferences 访问。
- 较大的账号列表和内容快照按 8000 字符分片存储，避免超过 Preferences 单值长度限制。
- 页面通过 `AuthStore` 或 `AppStore` 修改状态，不直接读写 Preferences。
- 密码使用随机盐和摘要保存，项目不会保存或输出用户输入的明文密码。
- 新登录会替换账号当前活动 Token，以模拟单设备在线。
- 冻结、注销或失效 Token 会阻止账号恢复会话。
- 强制注销采用 `DELETED` 状态，不物理删除用户、动态或审计记录。
- 账号、会话、动态、评论、消息、认领、线索和收藏均跨应用重启保留，并按账号隔离。

## 图片素材替换

当前信息流使用分类 Emoji 和颜色卡作为图片占位，不申请相册权限。后续添加真实图片时：

1. 将素材放入 `entry/src/main/resources/base/media/`。
2. 使用小写字母和下划线命名，例如 `post_phone.png`。
3. 在 Mock 数据中把 `imageKey` 映射到相应资源。
4. 不要把真实姓名、学号、手机号或校园卡号保留在图片中。

## 当前限制

- 没有真实后端、数据库或跨设备账号同步。
- 验证码不会通过短信或邮件发送。
- 单设备登录只通过本地活动 Token 模拟。
- 没有接入相册、相机、地图、推送、即时通信和内容审核服务。
- 密码摘要实现仅用于本地教学演示，不能替代生产服务端的 Argon2、bcrypt 或 scrypt。
- 尚未在模拟器、真机和实际平板设备上完成视觉与交互验收。
- 工程当前没有 Git 仓库信息，不包含提交或发布流程。

## 数据库版目标架构

真实多用户版本必须由后端服务访问数据库，HarmonyOS 客户端不能直接连接 PostgreSQL、MySQL 或其他服务端数据库。

```text
HarmonyOS 客户端
    │ HTTPS / JSON
    ▼
反向代理与 TLS（Nginx / 云网关）
    │
    ▼
业务 API 服务
    ├─ PostgreSQL / MySQL      结构化业务数据
    ├─ Redis（可选）           验证码、限流、短期会话
    ├─ 对象存储                失物图片
    └─ 短信 / 邮件服务         真实验证码
```

建议的参考交付栈是“Spring Boot 或 NestJS + PostgreSQL + Redis + Docker Compose”。如果使用华为云，也可以用 AppGallery Connect 的认证、云数据库、云存储和云函数替代自建服务。无论选择哪种方案，客户端只依赖稳定的 HTTPS API，不依赖数据库品牌。

### 数据库表

| 表 | 关键字段与约束 |
| --- | --- |
| `users` | `id`、昵称、真实姓名、身份、院系、校区、信用分、状态；昵称和学号/工号唯一 |
| `user_credentials` | `user_id`、手机号、学校邮箱、密码摘要；手机号和邮箱唯一 |
| `verification_codes` | 目标、用途、摘要、过期时间、重发时间、消费时间 |
| `sessions` | 用户、刷新令牌摘要、设备、签发/过期/撤销时间 |
| `posts` | 类型、分类、标题、描述、地点、时间、状态、发布者、版本号 |
| `post_images` | 帖子、对象存储 URL、排序、内容类型 |
| `comments` | 帖子、作者、内容、创建时间、软删除状态 |
| `post_likes` | 用户与帖子联合唯一索引 |
| `favorites` | 用户与帖子联合唯一索引 |
| `claims` | 帖子、申请人、特征说明、审核状态、审核人和时间 |
| `clues` | 帖子、提交人、地点/时间/描述、创建时间 |
| `notifications` | 接收人、类型、关联业务 ID、已读时间 |
| `audit_logs` | 操作人、目标用户、动作、原因、时间、请求追踪 ID |

用户注销采用状态标记而不是直接删除，避免破坏帖子、认领和管理员审计链。认领审核、确认归还、验证码消费及点赞计数等并发操作必须使用数据库事务或原子更新。

### API 最小契约

所有接口统一使用 `/api/v1` 前缀、JSON 请求/响应和 HTTPS。除注册、登录、验证码发送和刷新令牌外，其余接口携带 `Authorization: Bearer <access-token>`。

```text
POST   /api/v1/auth/codes                 发送短信或邮箱验证码
POST   /api/v1/auth/register              注册
POST   /api/v1/auth/login/password        密码登录
POST   /api/v1/auth/login/code            验证码登录
POST   /api/v1/auth/token/refresh         刷新访问令牌
POST   /api/v1/auth/logout                注销当前会话
GET    /api/v1/users/me                   当前用户
PATCH  /api/v1/users/me                   修改资料

GET    /api/v1/posts                      分页、搜索和筛选
POST   /api/v1/posts                      发布
GET    /api/v1/posts/{id}                 详情
PATCH  /api/v1/posts/{id}                 修改或关闭
POST   /api/v1/posts/{id}/likes           点赞
DELETE /api/v1/posts/{id}/likes           取消点赞
POST   /api/v1/posts/{id}/favorites       收藏
DELETE /api/v1/posts/{id}/favorites       取消收藏
POST   /api/v1/posts/{id}/comments        评论
POST   /api/v1/posts/{id}/claims          申请认领
POST   /api/v1/posts/{id}/clues           提交线索
PATCH  /api/v1/claims/{id}/review         发布者审核
PATCH  /api/v1/claims/{id}/return         确认归还

GET    /api/v1/notifications              消息列表
PATCH  /api/v1/notifications/{id}/read    标记已读
GET    /api/v1/admin/users                管理员筛选用户
PATCH  /api/v1/admin/users/{id}/status    冻结、解冻或注销
PATCH  /api/v1/admin/users/{id}/role      管理员授权
```

推荐响应结构：

```json
{
  "code": "OK",
  "message": "",
  "data": {},
  "requestId": "01H..."
}
```

列表接口应返回 `items`、`page`、`pageSize` 和 `total`。时间统一使用 UTC ISO 8601 字符串；ID 由服务端生成；客户端不能提交或覆盖 `ownerId`、`isAdmin` 等权限字段。

## HarmonyOS 客户端接入点

数据库版应尽量保持 `Index.ets` 页面结构不变，按以下边界替换：

1. 新增 `ApiClient.ets`，统一处理基础地址、JSON、超时、错误码、访问令牌和 401 刷新。
2. 新增 `AuthApiRepository.ets`，替换 `MockAuthService` 和本地账号列表。
3. 新增 `ContentApiRepository.ets`，提供帖子、评论、认领、线索和通知的资源级接口。
4. `AuthStore` 保留响应式状态，但登录、注册、资料和管理员方法改为异步 API 调用。
5. `AppStore` 的发布、点赞、收藏、评论和认领操作改为异步；后端成功后再更新顶层数组。
6. 移除 `Index.ets` 中的 `ContentSnapshot` 整包加载、`persistContent()` 和 `contentSaveQueue`。
7. `AccountRepository` 不再保存全量账号；Preferences 只保留非敏感设置和必要缓存。
8. access token/refresh token 等短敏感凭据使用系统安全能力保存，不写入日志或普通 Preferences。

当前 `entry/src/main/module.json5` 尚未声明网络权限。接入 API 时需要在 `module.requestPermissions` 中加入：

```json5
{
  "name": "ohos.permission.INTERNET"
}
```

基础地址必须按构建环境注入，例如调试环境 `https://api-dev.example.edu.cn/api/v1`、生产环境 `https://api.example.edu.cn/api/v1`，不得在业务页面散落硬编码地址。

## 后端与数据库部署约定

仓库补齐后端后，建议提供以下目录；当前工程尚未包含这些文件：

```text
server/
├─ src/                       # API 与领域服务
├─ migrations/                # 可审查、可回滚的数据库迁移
├─ tests/                     # 单元、集成和权限测试
├─ Dockerfile
├─ .env.example               # 只放变量名和安全示例
└─ README.md                  # 后端独立运行说明
deploy/
├─ compose.yaml               # API、数据库、Redis
├─ nginx.conf                 # TLS 终止与反向代理
└─ healthcheck/               # 健康检查脚本
```

### 环境变量

生产密钥只配置在部署平台，不提交 `.env`、数据库密码、短信密钥、JWT 私钥或 TLS 私钥。

```dotenv
APP_ENV=production
HTTP_PORT=8080
DATABASE_URL=postgresql://lostfound_app:CHANGE_ME@db:5432/lostfound
REDIS_URL=redis://redis:6379/0
ACCESS_TOKEN_TTL=15m
REFRESH_TOKEN_TTL=7d
JWT_PRIVATE_KEY_PATH=/run/secrets/jwt_private_key
SMS_PROVIDER_KEY=CHANGE_ME
MAIL_PROVIDER_KEY=CHANGE_ME
OBJECT_STORAGE_ENDPOINT=https://storage.example.com
OBJECT_STORAGE_BUCKET=lost-and-found
PUBLIC_ASSET_BASE_URL=https://cdn.example.edu.cn
```

### 首次部署流程

1. 准备独立数据库和最低权限业务账号，不使用数据库管理员账号运行应用。
2. 通过 Secret 管理器或容器 Secret 配置环境变量和密钥。
3. 执行数据库迁移；迁移失败立即停止，不允许应用自行重建生产数据库。
4. 启动 API 和 Redis，再检查 `/health/live` 与 `/health/ready`。
5. 配置域名、受信任 TLS 证书、反向代理、请求大小和超时限制。
6. 创建首个管理员时使用一次性初始化命令或离线迁移，不在客户端内置生产管理员密码。
7. 将客户端测试环境基础地址指向部署后的 API，完成注册、双方式登录和核心业务回归。
8. 完成备份恢复演练、日志脱敏检查和权限测试后，再切换生产域名。

参考命令应由后端实际技术栈提供。例如使用 Docker Compose 时：

```bash
docker compose -f deploy/compose.yaml config
docker compose -f deploy/compose.yaml up -d db redis
docker compose -f deploy/compose.yaml run --rm api migrate
docker compose -f deploy/compose.yaml up -d api nginx
docker compose -f deploy/compose.yaml ps
```

这些命令在当前仓库中尚不可执行，因为 `server/`、`deploy/compose.yaml` 和迁移文件还未创建。

### 数据初始化与迁移

- 演示账号只允许通过开发/测试环境 seed 创建，生产环境默认不导入。
- 不把客户端 Preferences 数据直接复制进生产库；如需迁移，应编写一次性导入器并做字段校验、去重和审计。
- 所有结构变化必须通过带版本号的迁移完成，并提供回滚或前向修复方案。
- 每日自动备份数据库，定期进行恢复演练；图片对象存储启用版本控制或生命周期策略。

## 安全要求

- 密码在服务端使用 Argon2id 或 bcrypt 等成熟算法；客户端不保存密码摘要。
- 验证码在服务端保存摘要，按账号、目标、设备/IP 和用途限流，成功使用后原子消费。
- 管理员、帖子所有者、认领审核和归还权限全部由服务端校验，不能相信客户端传入的角色或用户 ID。
- 使用 HTTPS，禁止通过关闭证书校验解决调试问题。
- 日志不得记录密码、完整验证码、Token、身份证明、完整手机号或邮箱。
- 刷新令牌、短信/邮件密钥和数据库凭据需要支持轮换与吊销。
- 图片上传校验文件头、类型、大小和数量，并使用随机对象键；展示前考虑内容审核和隐私遮挡。

## 数据库版验收门槛

- 数据库从空库执行全部迁移成功，重复执行不会破坏数据。
- 手机号/邮箱密码和验证码登录均通过，验证码不能跨目标、跨用途或重复使用。
- 两个账号在不同设备操作时，帖子、点赞、收藏、评论和消息不会串号。
- 并发点赞不产生重复记录，并发认领审核只允许一次有效状态转换。
- 普通用户无法调用管理员接口，也不能修改他人帖子或审核他人认领。
- 访问令牌过期后能安全刷新；刷新失败会清理本地会话并返回登录页。
- API/数据库不可用时客户端显示可恢复错误，不白屏、不永久加载、不丢失未提交表单。
- 数据库备份可以在隔离环境恢复，恢复后核心查询与登录可用。
- HarmonyOS 客户端测试、ArkTS 编译、后端测试、数据库集成测试和真机流程全部通过。

## 官方参考

- [HarmonyOS 开发文档中心](https://developer.huawei.com/consumer/cn/doc/)：ArkTS、ArkUI、ArkData、Network Kit 和应用配置。
- [Network Kit：连接网络](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/network-kit-network-connecttion)：端云网络连接能力。
- [Asset Store Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V14/asset-store-kit-overview-V14)：Token 等短敏感数据的安全存储边界。
- [HarmonyOS 应用设计与开发](https://developer.huawei.com/consumer/cn/app/planning)：HarmonyOS 应用能力与开发入口。

## 许可证

项目当前未声明开源许可证。在补充许可证前，请勿默认将代码用于公开分发或商业用途。
#   L o s t A n d F o u n d  
 