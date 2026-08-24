# API

基础路径：`/api/video-knowledge/v1`。字段使用 `snake_case`，时间使用带时区 ISO 8601。

## `GET /system/health`

返回数据库与受监管 Worker 健康状态、版本和时间。

## `GET /system/runtime`

返回 RC 必需媒体组件的可用状态和安全版本信息：yt-dlp、streamget、faster-whisper、FFmpeg、
ffprobe。响应不包含可执行文件完整路径。

## Jobs

- `POST /sources/ingest`：创建普通视频采集任务。
- `POST /sources/live`：创建直播监控/录制任务。
- `GET /jobs?status=RUNNING&limit=50`：获取权威任务快照。
- `GET /jobs/{id}`：获取单个任务。
- `GET /jobs/{id}/events`：获取持久化状态和进度事件。
- `POST /jobs/{id}/cancel`：排队任务立即取消，运行任务设置协作取消标记。
- `POST /jobs/{id}/pause`、`resume`、`retry`：严格按状态机执行。

## WebSocket

连接 `/api/v1/ws?client_id=...&last_event_id=...`。事件包含 `event_id`、`type`、
`occurred_at` 和 `data`。断线重连时携带最后事件 ID，前端仍以 REST 快照为事实来源。
