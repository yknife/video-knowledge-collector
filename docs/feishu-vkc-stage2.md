# 飞书 VKC 阶段 2：持久化 workflow、订阅和任务关联

验收日期：2026-09-06。阶段 2 已完成。消息采集现在使用独立的 workflow 和可信订阅持久化长任务身份，
INGEST_VIDEO 与 ANALYZE 通过非敏感外键关联。终态主动投递尚未启用。

## 数据模型

Alembic revision `20260906_0008` 新增：

- `collection_workflows`：Source、Media、ingest job、analysis job、派生状态、终态原因和完成时间；
- `workflow_subscriptions`：workflow、可信 Feishu origin、请求者、投递策略、所有者标志和入站幂等键；
- `notification_outbox`：通知类型、订阅、状态、尝试次数、下次尝试、租约、稳定幂等键和安全 payload；
- `jobs.workflow_id` 与 `jobs.parent_job_id`：只保存非敏感关联，可通过 Job API 读取。飞书目标不进入
  `input_json`、`result_json` 或公开 Job 字段。

阶段 1 的 `collection_requests` 保留为兼容审计数据。migration 会把已有回执转换为 workflow 和 owner
subscription，并恢复 ingest/analysis 的 workflow 与父子关联。migration 已验证 `0007 -> 0008 -> 0007`
升级和回滚。

## workflow 语义

- 同一入站 `platform/chat/message` 只创建一个 subscription，重复事件返回原 workflow/job。
- 不同用户提交同一个活动 Source 时共享 workflow 和 Job，各自创建可信 subscription；只有首个 owner 能取消
  共享任务，其他订阅者只能查询，避免任一后来订阅者中断所有人的工作流。
- `JobStateMachine` 在创建、领取、进度、失败、取消、恢复、重试和完成事务中同步 workflow 投影。Worker
  不直接修改 workflow 状态。
- ingest 创建 analysis 时传播 `workflow_id` 和 `parent_job_id`。子任务创建使用 `BEGIN IMMEDIATE` 原子检查；
  在“子任务已创建、父任务尚未完成”的崩溃窗口重试时复用原 analysis job。
- ingest 成功但 analysis 未成功时 workflow 保持 `ANALYZING`。analysis 的成功、部分成功、失败或取消才形成
  对应 workflow 终态；analysis 重试会把 workflow 恢复为 `ANALYZING`，不会创建第二份 subscription。
- 已有 READY 知识时不重新下载或分析；系统创建完成态 workflow/subscription 和一个稳定幂等的 PENDING
  Outbox 记录。阶段 3 将为普通终态实现通用事务 projector 与 Outbox 租约恢复。

## 验收覆盖

- 同消息重放：一个 workflow、一个 subscription、一个 ingest job；
- 多用户同 URL：一个活动 workflow/job、两个隔离 subscription，非 owner 不能取消；
- 父子窗口：ingest 完成后 workflow 为 `ANALYZING`，analysis 成功后才为 `SUCCEEDED`；
- 故障恢复：关闭并重新打开数据库后 workflow、subscription、父子 Job 关联和状态可恢复；
- 失败与重试：analysis 失败投影为 `FAILED`，重试回到 `ANALYZING`，最终成功且 subscription 数量不变；
- 缓存命中：READY 知识不创建 Job，立即生成完成态 workflow 和 PENDING Outbox；
- 配额、原请求者访问控制、取消状态机、工具可信上下文和阶段 1 Schema 防伪造继续通过。

自动化结果：完整 `scripts/check.ps1` 通过，其中 Video Knowledge 160 项、Gateway API 118 项、Windows
安装脚本 1 项、Desktop TypeScript/ESLint 和 Vitest 29 项均成功。Windows 同一时钟刻度内的事件 ID 时间
前缀改为进程内严格递增，相关游标顺序测试连续运行 10 次通过。

## 后续边界

`notification_outbox` 当前只承载 READY 缓存命中的即时终态记录，没有 dispatcher。阶段 3 将加入通用终态
projector、事务性 Outbox 写入、租约、退避、死信与 reconciliation；阶段 4 才会把确定性结果投递到原飞书
聊天和话题。
