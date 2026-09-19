# API

基础路径：`/api/video-knowledge/v1`。字段使用 `snake_case`，时间使用带时区 ISO 8601。

飞书消息采集的参数契约和运维配置见 [阶段 0 记录](feishu-vkc-stage0.md)，可信上下文与工具见
[阶段 1 记录](feishu-vkc-stage1.md)，持久化 workflow/订阅/任务关联见
[阶段 2 记录](feishu-vkc-stage2.md)。消息采集不新增 REST 端点；现有 Desktop API 不受默认关闭的消息
采集开关影响。

消息写入工具只在受信任的飞书 invocation context 中注册。生产启用前必须同时满足：

- `FEISHU_ALLOWED_USERS` 只包含获准用户，且 `FEISHU_ALLOW_ALL_USERS=false`；
- `VKC_MESSAGING_INGEST_ENABLED=true`，允许平台保持默认的 `feishu`；
- VKC 数据库已迁移到 head，Worker、Feishu adapter 和 NotificationDispatcher 均健康；
- 存储余量、单用户和单聊天配额满足要求。

`collect_video` 只接受一个 B 站点播 URL。成功受理返回 `workflow_id`、权威状态、是否复用和是否命中缓存；
`get_collection_status`、`cancel_collection`、`retry_collection` 可省略 ID 并解析当前可信会话最近任务。终态结果由
Outbox 异步回复原消息/话题。常见安全错误码包括 `UNSAFE_URL`、`RATE_LIMITED`、`AUTH_REQUIRED`、
`MEDIA_UNAVAILABLE`、`STORAGE_LIMIT` 和 Hermes/分析错误；响应不会包含 Cookies、密钥、路径或原始命令输出。

## `GET /system/health`

返回数据库与受监管 Worker 健康状态、版本和时间。

## `GET /system/runtime`

返回 RC 必需媒体组件的可用状态和安全版本信息：yt-dlp、streamget、faster-whisper、FFmpeg、
ffprobe。响应不包含可执行文件完整路径。

## Jobs

- `POST /sources/ingest`：创建普通视频采集任务。可选同时提供 `analysis_provider` 和
  `analysis_model`，仅覆盖该内容后续 Hermes 知识分析所用模型；两者都省略时继承 Hermes 全局模型。
- `POST /sources/local`：从 Hermes 所在设备的本地视频文件创建采集任务；请求需提供
  `path`、`title`，可选 `author`、ASR 参数、自动分析开关以及成对出现的
  `analysis_provider`/`analysis_model`。Worker 会把源文件复制到受管存储，
  不移动或删除原文件。
- `POST /sources/live`：创建直播监控/录制任务；任务级分析模型选择会随录制后的处理任务继续传递。
- `GET /jobs?status=RUNNING&limit=50`：获取权威任务快照。
- `GET /jobs/{id}`：获取单个任务。
- Job 响应包含非敏感的 `workflow_id` 和 `parent_job_id`；消息平台、会话、聊天、线程、消息和用户目标只保存在
  内部 subscription 表，不进入 Job 输入或公开 Job 响应。
- `GET /jobs/{id}/events`：获取持久化状态和进度事件。
- `POST /jobs/{id}/cancel`：排队任务立即取消，运行任务设置协作取消标记。
- `POST /jobs/{id}/pause`、`resume`、`retry`：严格按状态机执行。

## WebSocket

连接 `/api/v1/ws?client_id=...&last_event_id=...`。事件包含 `event_id`、`type`、
`occurred_at` 和 `data`。断线重连时携带最后事件 ID，前端仍以 REST 快照为事实来源。

## Hermes 知识结果降级标记

`GET /media/{media_id}/knowledge` 返回的 `summary.content` 在存在字幕兜底分析时包含
`degraded=true` 和 `degraded_ranges`。每个范围包含 `chunk_index`、稳定的 `reason` 代码以及带
`segment_ids`、`start_ms`、`end_ms` 的 `citation`。分类文档中的兜底条目同时包含
`degraded=true` 和 `degradation_reason`；正常模型结果的该字段为 `false`。
