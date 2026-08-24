# API

基础路径：`/api/v1`。字段使用 `snake_case`，时间使用带时区 ISO 8601。

## `GET /system/health`

返回 API 与数据库健康状态、版本、环境、时间及当前 `request_id`。请求可携带
`X-Request-ID`；否则服务端生成 `req_` 前缀标识，响应头与响应体均会返回。

## Jobs

- `POST /jobs`：创建持久化任务；Sprint 2 支持 `DEMO` 类型。
- `GET /jobs?status=RUNNING&limit=50`：获取权威任务快照。
- `GET /jobs/{id}`：获取单个任务。
- `GET /jobs/{id}/events`：获取持久化状态和进度事件。
- `POST /jobs/{id}/cancel`：排队任务立即取消，运行任务设置协作取消标记。
- `POST /jobs/{id}/pause`、`resume`、`retry`：严格按状态机执行。

## WebSocket

连接 `/api/v1/ws?client_id=...&last_event_id=...`。事件包含 `event_id`、`type`、
`occurred_at` 和 `data`。断线重连时携带最后事件 ID，前端仍以 REST 快照为事实来源。
