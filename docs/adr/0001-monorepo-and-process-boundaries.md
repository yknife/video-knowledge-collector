# ADR-0001：Hermes 内聚与进程边界

- 状态：已接受（Sprint 6 修订）
- 日期：2026-08-19

## 背景

VKC 最初采用独立 Web、API、Worker 的单仓库结构。Sprint 6 要求 Hermes Desktop 成为唯一入口，
VKC 使用 Hermes 侧边栏和共享 Gateway，用户不再分别启动两套应用。

## 决策

所有活动前后端代码迁入 `thirdparty/hermes-agent`：React UI 位于 Desktop 插件目录，Python
应用服务、Worker、适配器和迁移位于 `plugins/video_knowledge/backend`。VKC 路由直接注册到
`gateway/platforms/api_server.py`，复用 Hermes 的认证、profile 和监听端口；Hermes 生命周期
负责数据库迁移以及 Worker 的启动、监管和停止。

## 后果

启动 Hermes Desktop 即可使用侧边栏 VKC。VKC 不再拥有独立 HTTP 监听器、独立前端开发服务器
或第二套网关密钥。旧 Sprint 1–5 工程仅归档在
`thirdparty/hermes-agent/archive/video_knowledge_pre_migration`，不参与运行和发布打包。
