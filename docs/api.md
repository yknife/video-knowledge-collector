# API

基础路径：`/api/video-knowledge/v1`。字段使用 `snake_case`，时间使用带时区 ISO 8601。

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
