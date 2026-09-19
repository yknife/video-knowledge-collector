# 飞书 VKC 阶段 1：可信上下文与采集工具

验收日期：2026-09-06。阶段 1 已完成。飞书会话可以调用三个 VKC 消息工具；新采集仍受
`VKC_MESSAGING_INGEST_ENABLED` 控制，默认关闭。阶段 1 只负责受理、查询与取消，不包含终态主动推送。

## 已实现行为

- Gateway 从已通过入站门控的 `MessageSource` 构造只读 `ToolInvocationContext`，包含 profile、session、
  platform、chat、thread、message、user 和授权结果。上下文通过 `ContextVar` 进入工具执行线程，并在 turn
  结束后恢复；这些字段不会进入 prompt 或模型可见的 JSON Schema。
- 三个写入/控制工具位于独立的 `video_knowledge_messaging` 工具集。工具集只允许在 Feishu 平台解析，避免
  Desktop、CLI 或其他消息平台看到写入 Schema。此会话级隔离不使用会被进程级缓存的 `check_fn`。
- handler 每次调用都会再次校验当前 profile、Feishu 平台、授权结果以及非空的 user/chat/message/session
  身份。模型只能提供 `url` 或 `workflow_id`；伪造 `chat_id`、用户、路径、Cookies、回调地址等额外字段会被
  Pydantic `extra=forbid` 拒绝。
- `collect_video(url)` 只接受阶段 0 契约允许的 B 站普通视频与 b23.tv 短链，强制 `auto_analyze=true`，写入
  ingest job、CREATED 事件和受理回执后立即返回，不等待探测、下载、ASR 或分析。
- 同一 `platform/chat/message` 派生稳定 `workflow_id`。SQLite `BEGIN IMMEDIATE` 把配额检查、Source、Job、
  JobEvent 和 `collection_requests` 回执放在同一个原子受理区间；重复事件返回原 workflow/job，不增加配额。
- `get_collection_status` 和 `cancel_collection` 按 platform/user 校验原请求者。取消只调用
  `JobStateMachine`，不删除媒体；查询结果不含投递目标、输入 JSON、路径或原始 provider 错误。
- 消息采集的最大清晰度写入任务输入。Worker 在下载前使用可信 probe 结果执行最大时长限制；时长未知、
  非正数或超限时拒绝消息采集任务，不改变 Desktop 采集流程。

## 数据库变更

Alembic revision `20260906_0007` 新增 `collection_requests`：保存最小可信来源、稳定 workflow ID 和 ingest
job 关联，并以 `(platform, chat_id, message_id)` 唯一约束阻止重复受理。该表是阶段 1 的幂等回执；阶段 2
会引入完整的 workflow、订阅、父子任务和多订阅者复用模型。

## 验收结果

- 可信上下文嵌套、线程传播、并发 turn 隔离和 turn 后清理通过。
- Gateway 实际 turn 绑定使用事件 message ID 与 Feishu ACL 结果；Feishu 工具集仅在 Feishu 平台解析。
- 同一消息重放只生成一个 Job；跨用户查询/取消返回统一不可访问；取消产生持久化状态事件。
- 模型传入伪造 `chat_id` 被 Schema 拒绝，实际 handler 只使用绑定上下文中的 chat/user/message。
- 功能开关、单用户活动数、UTC 单日提交量、最大清晰度和最大时长均在服务或 Worker 边界执行。
- migration 从 `20260822_0006` 升级到 `20260906_0007` 后，表、唯一约束和用户查询索引存在。
- 自动化验证：Video Knowledge 155 项通过；Feishu/可信上下文/路由选择 110 项通过；阶段 1 聚焦用例
  38 项通过。完整 `scripts/check.ps1` 通过，其中 Gateway API 118 项、Windows 安装脚本 1 项、Desktop
  typecheck/ESLint 和 Vitest 29 项均通过。

## 运行说明与后续边界

升级后先执行 migration，再在目标 profile 的 `.env` 设置 `VKC_MESSAGING_INGEST_ENABLED=true` 并重启
Hermes。若用户曾显式保存 Feishu 工具集配置，需要确认 `video_knowledge_messaging` 未被关闭。关闭采集开关
会拒绝新的 `collect_video` 请求；既有任务继续运行，状态与取消服务本身不修改该开关。

阶段 1 尚不提供异步终态飞书通知，也不承诺不同用户提交同一 URL 时复用同一个活动 workflow。阶段 2–4
将增加完整 workflow/subscription、分析父子关联、事务性 Outbox 和稳定原会话投递。
