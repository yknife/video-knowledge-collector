# Architecture

Hermes Desktop 是唯一用户入口和唯一进程主管。Video Knowledge Collector 作为默认启用的
Hermes bundled plugin 交付，不再运行独立 Vite/FastAPI 产品。

- Desktop UI：`thirdparty/hermes-agent/apps/desktop/src/plugins/video-knowledge`
- transport-neutral 应用层：`thirdparty/hermes-agent/plugins/video_knowledge/backend/app`
- durable Worker：`thirdparty/hermes-agent/plugins/video_knowledge/backend/worker`
- 公共 Gateway：`thirdparty/hermes-agent/gateway/platforms/api_server.py`
- profile 数据：`HERMES_HOME` 下的 VKC SQLite、媒体和模型缓存

Hermes 启动时按 profile 执行迁移并监管 Worker；所有状态变更仍经 `JobStateMachine`，Worker
写入前必须持有有效租约。媒体命令只允许从 `backend/media_adapters` 发起。

## Windows RC

Windows RC 复用 Hermes Electron Builder 的 NSIS/MSI 链路。React 静态资源进入 `app.asar`，
首次启动由经过签章元数据固定的 `thirdparty/hermes-agent/scripts/install.ps1` 安装 Hermes 管理的 Python 运行时。
安装签章同时包含 fork 仓库、分支和不可变提交，防止 VKC 构建错误回退到官方 Hermes 源码。

不再生成独立 VKC PyInstaller 服务：迁移后的系统没有独立 VKC HTTP/Worker 产品进程；再次冻结
一套 Python onedir 会复制 Hermes Gateway、破坏 profile/升级语义，并违反单入口边界。具体决策见
ADR 0002。
