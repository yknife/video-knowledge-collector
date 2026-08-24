# Video Knowledge Collector

Windows 优先、本地优先的视频知识采集系统。当前仓库已推进到详细设计文档中的
**Sprint 10：Windows 打包与发布候选**。Hermes Desktop 是唯一用户入口，视频知识采集以
默认启用的侧边栏插件运行，不再单独启动 VKC Web/API。

## 已实现

- Hermes Desktop `/video-knowledge` 工作区与“视频知识”侧边栏入口
- 两步式 URL 探测与确认、画质/字幕语言、自动分析和逐任务 ASR 参数
- tiny/base/small/medium/large-v3 faster-whisper 模型与 CPU/CUDA/精度选择
- 完整任务中心：筛选、进度、错误、事件、暂停、恢复、取消和重试
- 媒体资产列表、本地 Range 视频预览、Transcript 搜索和字幕点击跳转
- ASR 设备检测、当前默认配置、模型资源与 CPU/GPU 建议
- Hermes `api_server.py` 下的 `/api/video-knowledge/v1/*` API，共用 Gateway 认证与 profile
- Hermes 托管的迁移、Worker 启停、父进程退出检测与退避重启
- Hermes Client（Chat Completions/Responses）、Transcript Map-Reduce 和 JSON Schema 校验
- 版本化摘要、章节、知识点、建议问答及 Transcript 时间引用
- transport-neutral 应用服务和 Python 共享包
- React 19 + TypeScript + Vite + Router + TanStack Query + Zustand
- SQLite WAL / foreign keys / busy timeout、SQLAlchemy 2、Alembic
- JSON 结构化日志和端到端 `X-Request-ID`
- 前端仪表盘实时调用后端健康检查
- SQLite 持久化任务队列、严格状态机、Worker 原子领取和租约恢复
- Jobs REST API、WebSocket 增量事件与支持取消/暂停/恢复/重试的任务中心
- URL 规范化与来源去重、yt-dlp 探测/下载、ffprobe 媒体校验
- Source、MediaItem、MediaAsset 持久化及文件哈希登记
- “添加内容”探测确认流程和本地媒体库页面
- 人工/自动字幕选择与下载，支持 SRT、VTT、ASS/SSA、yt-dlp JSON3
- Transcript 规范化、相邻重复字幕合并、版本化文件和 SQLite FTS5 全文搜索
- 媒体详情页、本地 Range 视频播放、字幕时间轴与点击跳转
- 无字幕自动回退 faster-whisper，FFmpeg 抽取 16 kHz 单声道 PCM 音频
- CPU/NVIDIA GPU 自动检测、模型复用、VAD、词时间戳和语言配置
- 长音频重叠分片、边界去重、分片检查点续跑、进度与安全点取消
- 添加内容页 ASR 选项和独立的 ASR 设置/资源提示页面
- Ruff、mypy、pytest、ESLint、Vitest、TypeScript build 和 GitHub Actions

## 环境要求

- Python 3.11 或 3.12
- [uv](https://docs.astral.sh/uv/)
- Node.js 22.22+
- npm（Hermes 当前要求 `<11.10` 或 `>=11.17`）
- FFmpeg（需确保 `ffmpeg`、`ffprobe` 位于 PATH；也可分别通过
  `VKC_FFMPEG_PATH`、`VKC_FFPROBE_PATH` 配置）

## 一键启动

在 PowerShell 中执行：

```powershell
.\scripts\dev.ps1
```

脚本首次运行会同步 VKC/Hermes 依赖，然后只启动 Hermes Desktop。Hermes 启动后会：

- 自动加载“视频知识”侧边栏与 `/video-knowledge` 工作区；
- 在当前 Hermes profile 下执行 VKC 数据库迁移；
- 拉起并监管持久化 Worker；
- 在 Hermes API Server 注册 `/api/video-knowledge/v1/*`；
- 通过同一个 Gateway 调用当前 Hermes 模型生成知识结果。

开发脚本会为 loopback API Server 生成本次进程使用的强随机密钥，并启用共享网关；密钥不会写入日志。
Hermes 仍需按其首次启动引导配置模型/provider。

复制 `thirdparty/hermes-agent/plugins/video_knowledge/backend/.env.example` 为 Hermes 工作目录下的
`.env` 可覆盖默认配置。

## 验证

```powershell
.\scripts\check.ps1
```

## Windows RC

在干净的 `vkc-integration` 提交上构建默认 NSIS 安装包：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-rc.ps1
```

输出位于 `artifacts/windows-rc`，包含安装程序、`install-stamp.json`、SHA-256 和
`release-manifest.json`。安装包会固定到 `yknife/hermes-agent` 的确切提交，首次启动不会回退到
官方 Hermes 仓库。MSI 或两种格式可通过 `-Target msi` / `-Target all` 构建。

完整安装说明见 [Windows RC 用户手册](docs/windows-rc-user-guide.md)，发布人员应同时执行
[发布清单](docs/windows-rc-release-checklist.md)。

规范 API 前缀是 `GET /api/video-knowledge/v1/system/health`。来源采集使用
`POST /api/video-knowledge/v1/sources/ingest`，媒体库使用
`GET /api/video-knowledge/v1/media`，知识结果使用
`GET /api/video-knowledge/v1/media/{id}/knowledge`。这些接口使用 Hermes `API_SERVER_KEY`
Bearer 认证；Desktop 侧边栏通过同一 Hermes Gateway 的 profile/session 认证插件别名访问。

首次转写会由 faster-whisper 下载所选模型并缓存，耗时取决于网络和模型大小。默认
`small + auto + int8/float16`；CPU 建议 `small`，NVIDIA GPU 可选 `medium` 或
`large-v3`。Windows 安装会在项目虚拟环境中同步 CUDA 12 cuBLAS/cuDNN 运行库，首次同步
约需额外下载 1.3 GiB；不要求系统安装完整 CUDA Toolkit。模型下载中断后可由模型缓存继续，
而音频转写中断后会复用已完成的分片检查点。

## 目录

- `thirdparty/hermes-agent/plugins/video_knowledge/backend/app`：transport-neutral 应用服务、配置、生命周期和持久化协调
- `thirdparty/hermes-agent/plugins/video_knowledge/backend/worker`：由 Hermes 监管的 durable Worker
- `thirdparty/hermes-agent/apps/desktop/src/plugins/video-knowledge`：Hermes 侧边栏 UI
- `thirdparty/hermes-agent/gateway/platforms/api_server.py`：唯一公共 API Gateway
- `thirdparty/hermes-agent/plugins/video_knowledge/backend`：Worker、Hermes Client、媒体/转写适配器与 Alembic migrations
- `thirdparty/hermes-agent/plugins/video_knowledge/backend/prompts`：VKC 版本化 AI Prompt
- `thirdparty/hermes-agent/archive/video_knowledge_pre_migration`：Sprint 1–5 独立 Web/根工程归档，不参与运行或打包
- `thirdparty/hermes-agent/plugins/video_knowledge/backend/config`：默认配置与日志配置示例
- `docs/adr`：架构决策记录
- `scripts`：Windows 开发、校验、RC 构建和制品完整性检查脚本
