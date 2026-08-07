# VMware 外部 MySQL 部署设计

## 目标

Linux VMware 虚拟机运行 Node.js API、Nginx 和本地图片卷；Windows 主机保留现有 MySQL 8 数据库。Linux API 使用 Windows 的 VMnet8 IPv4 地址连接 MySQL，不使用 `localhost`。

## 边界

- Docker Compose 仅启动 `api`、`nginx` 和 `lostfound_uploads` 图片卷。
- MySQL 不由 Compose 创建、不运行 Knex 迁移、不执行 SQL 脚本。
- Windows 主机只对 VMnet8 网段和 Linux 虚拟机 IP 开放 TCP 3308；MySQL 用户权限限定在该网段。
- API 使用 `DATABASE_URL`、`APP_JWT_SECRET` 等私有环境变量；仓库模板只保留占位符。

## 运维流程

先在 Windows MySQL 执行已审查的 schema/seed SQL，再配置 MySQL 监听、最小权限用户和 Windows 防火墙。将项目复制到 Linux VM，使用私有环境文件运行 Compose。Nginx 对外暴露 API 与 `/uploads/`，图片仅在 Linux 的 Docker 卷中保存。
