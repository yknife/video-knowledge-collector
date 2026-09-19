# 飞书 VKC 闭环阶段 3：事务性 Outbox 与恢复

验收日期：2026-09-06。阶段 3 已完成。Job 终态、workflow 终态和每个订阅的通知记录现在在同一个数据库
事务中提交；投递进程崩溃后可以依靠独立通知租约继续领取，不会占用或修改 VKC Worker 的 Job lease。

## 已完成范围

- `JobStateMachine` 的 workflow projector 在分析成功、采集/分析失败、部分完成或取消的终态事务内，为每个
  `TERMINAL` 订阅写入一条 `WORKFLOW_TERMINAL` Outbox。唯一键为
  `workflow_id:subscription_id:terminal`，重复 projector、任务重试和 reconciliation 不会增加第二条记录。
- Outbox payload 只保存 workflow 状态、media ID 和安全错误码。飞书 chat/thread/message/user 等可信路由仍只
  位于订阅表；数据库和事件不保存 App Secret、access token、Cookies、Authorization header、签名 URL、
  命令 stderr 或完整远端错误文本。
- `OutboxService` 提供 `claim`、`heartbeat`、`acknowledge`、`fail` 和 `release_due`。领取使用 SQLite
  `BEGIN IMMEDIATE` 串行化竞争；通知租约与 Job lease 完全分离。远端发送前或发送后、确认前崩溃时，租约
  到期后会重新进入 `RETRY`，保持至少一次投递语义。
- 临时错误按失败次数执行有上限的指数退避；默认最多 8 次、初始 5 秒、上限 900 秒。认证、授权、目标撤销
  等稳定错误直接进入 `DEAD`。错误码经过严格字符白名单清洗，原始异常文本不会进入 Outbox 或运维事件。
- revision `20260906_0009` 新增 `notification_outbox_events`，持久化 queued、claimed、lease renewed、
  released、retry scheduled、acknowledged 和 dead 生命周期。迁移会为阶段 2 已有 Outbox 补 queued 事件。
- 每个 profile 的 `ManagedVideoKnowledgeRuntime` 在迁移后、Worker 启动前执行 reconciliation：释放过期领取，
  并为所有终态 workflow 补齐缺失的唯一 Outbox。重复启动不会产生重复通知。

新增运维配置：

- `VKC_NOTIFICATION_LEASE_SECONDS`，默认 `30`；
- `VKC_NOTIFICATION_MAX_ATTEMPTS`，默认 `8`；
- `VKC_NOTIFICATION_RETRY_BASE_SECONDS`，默认 `5`；
- `VKC_NOTIFICATION_RETRY_MAX_SECONDS`，默认 `900`。

## 验收覆盖

- 普通 ingest/analysis 终态事务生成 Outbox；ingest 已完成但 analysis 未完成时没有成功通知。
- 注入 Outbox 写入故障后，Job 和 workflow 终态同时回滚，不会形成“已完成但通知未提交”的半状态。
- 两个并发 sender 只能有一个取得同一通知租约；错误 owner 和过期 owner 无法 heartbeat 或确认。
- 在领取后模拟进程崩溃，`release_due` 可恢复并由另一 sender 领取；崩溃恢复不消耗远端失败次数。
- 临时错误进入有界退避，稳定认证错误进入 `DEAD` 并产生只含安全错误码的持久化运维事件。
- 删除终态 workflow 对应 Outbox 后执行 reconciliation，首次补一条、再次执行补零条。
- migration 从 `20260906_0008` 升级会为旧 Outbox 回填事件，并能随完整 downgrade 删除阶段 3 表。
- 完整 `scripts/check.ps1` 通过：167 项 VKC、118 项 Gateway API、1 项 Windows 安装测试、Desktop
  typecheck/ESLint 和 29 项 Vitest 均成功。

## 阶段边界

阶段 3 没有调用飞书 API，也没有启动通知 dispatcher。实际异步投递、稳定发送 UUID、原聊天/话题路由、
消息分块和确定性结果渲染属于阶段 4。当前 PENDING/RETRY Outbox 会安全保留，等待阶段 4 消费。
