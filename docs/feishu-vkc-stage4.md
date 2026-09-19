# 飞书 VKC 闭环阶段 4：Gateway 异步投递与确定性渲染

验收日期：2026-09-06。阶段 4 已完成。Hermes Gateway 现在为每个已有 VKC 数据库的 profile 启动唯一的
`NotificationDispatcher`，消费阶段 3 的事务性 Outbox，并通过该 profile 已连接的飞书适配器把终态结果送回
原会话。Worker 不依赖 Gateway 或飞书实现。

## 投递生命周期

- Gateway 完成主 profile 和多 profile 平台连接后，按权威 profile 列表启动托管 VKC runtime；通知 runtime
  不启动第二个 Worker。Gateway 关闭时先停止 Dispatcher，再断开飞书适配器。
- Dispatcher 仅在飞书适配器可用时领取 Outbox，发送期间按独立通知租约续约。发送成功后确认 `DELIVERED`；
  临时网络、超时和限流错误进入阶段 3 的有界退避，稳定授权或目标错误进入 `DEAD`。
- Gateway 崩溃留下的 `IN_FLIGHT` 会由启动 reconciliation 释放。重启后的 Dispatcher 从原 Outbox 继续，
  每个分片仍使用相同幂等键。
- 投递目标只来自 `workflow_subscriptions` 保存的可信 `chat_id`、`thread_id` 和原 `message_id`。Dispatcher
  不接受模型指定目标，也不会把目标复制到 Job payload。
- 无法投递原目标时，只向该 profile 配置的飞书 home channel 发送包含 Outbox ID、workflow ID 和安全错误码的
  运维告警。告警不含标题、摘要、Transcript、知识内容、文件路径或远端错误文本。

## 飞书路由与幂等

- 首条及后续分片都回复原消息，并携带原话题 ID。原消息撤回时继续使用飞书适配器原有策略：普通聊天可安全
  回退到 chat；话题内回复失败会返回失败，禁止向群聊顶层新建消息。
- 每个渲染分片的键为 `notification_id:part:N`。飞书适配器用 UUID v5 从该键派生请求 UUID；SDK 网络重试、
  Outbox 重试和 Gateway 重启都复用同一个 UUID。若适配器再次拆分超长文本，则追加稳定的 chunk 编号，避免
  一个通知内的不同消息错误共享 UUID。
- 运维告警使用独立的 `notification_id:alert`，与用户结果分片不会冲突。

## 确定性结果模板

- 成功通知包含标题、作者、时长、短摘要、最多 5 个章节、5 个知识点、3 个建议问答、分析版本、workflow ID
  和 media ID。第一部分先展示结论，详情随后发送。
- `PARTIAL` 或 summary 中存在 degradation metadata 时，标题明确标记含兜底内容，并列出最多 12 个
  Transcript fallback 时间范围，不把字幕兜底描述成完整模型分析。
- 失败或取消通知只展示安全错误码、当前 Job 阶段、是否可重试、固定操作建议以及追踪 ID；不读取或渲染
  `Job.error_message`。
- 模型产生的标题、作者、摘要、章节、知识点和问答均视为不可信文本。渲染器先合并空白、执行字段与条目
  上限，再转义 Markdown 控制字符。渲染过程不调用 Hermes Agent，也不把 Transcript 或知识文本作为指令。
- 消息按 6000 字符以内的逻辑段落确定性分块，每块带 `通知 N/M` 和稳定幂等键。

## 验收覆盖

- 成功、降级和失败模板；fallback 时间范围；不可信 Markdown 转义；错误详情、路径与凭据不进入通知。
- 超长章节、知识点和问答按编号分块，重渲染获得相同分片键。
- 注入飞书临时失败后 Outbox 进入 `RETRY`；模拟 Gateway 重启后由新 owner 领取、复用原分片键并确认
  `DELIVERED`。
- 原 chat/topic/reply message 三元路由保持不变；话题目标缺失被识别为稳定目标错误。
- 注入不可投递目标后 Outbox 进入 `DEAD`，home channel 只收到无视频私密内容的告警。
- 飞书 SDK 请求首次超时后，三次网络尝试使用同一 UUID；不同通知分片使用不同的稳定 UUID。
- `ManagedVideoKnowledgeRuntime` 的 Alembic 初始化不会重置或禁用 Gateway 已配置的日志器；真实 Gateway
  重启后记录 `Video Knowledge notification dispatchers active: 1`，飞书与 webhook 均保持在线。
- 完整 `scripts/check.ps1` 通过：177 项 VKC、120 项 Gateway、1 项 Windows 安装检查、Desktop
  typecheck/ESLint 和 29 项 Vitest 均成功；额外的完整飞书与 VKC 组合回归为 251 项通过。

阶段 4 不改变数据库 schema，继续使用 revisions `20260906_0008` 和 `20260906_0009`。状态查询、自然语言
取消/重试和交互体验属于阶段 5；安全、配额与 B 站错误映射的完整加固属于阶段 6。
