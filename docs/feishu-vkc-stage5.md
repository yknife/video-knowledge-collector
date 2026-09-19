# 飞书 VKC 闭环阶段 5：会话状态、取消与重试

验收日期：2026-09-07。阶段 5 已完成第一迭代的文字交互闭环。飞书用户可以询问“刚才的视频处理到哪里了”、
“取消刚才的视频任务”或“重试刚才的视频任务”，无需从历史消息复制 Workflow ID。显式 Workflow ID 仍可用于
操作较早的任务。

## 会话解析与权限

- `get_collection_status`、`cancel_collection` 和新增的 `retry_collection` 接受可选 `workflow_id`。省略时只在
  可信 invocation context 的 profile、platform、user、chat 和 thread 范围内选择最近订阅；模型不能传入或覆盖
  这些字段。
- 查询允许 workflow 的订阅者执行。取消和重试只允许 `is_owner=true` 的原始 owner；其他用户、其他聊天和其他
  话题统一返回不可访问，不泄露 workflow 是否存在。
- 查询返回权威 workflow/job 状态、阶段、0–100 进度、取消标记、是否可重试及固定中文状态说明。它不读取
  Job 原始异常、命令输出、路径或凭据。

## 取消与重试

- 取消继续调用 `JobStateMachine.request_cancel`。排队任务直接进入取消终态，运行中任务设置取消请求，由持有租约的
  Worker 完成安全终止；重复取消保持幂等，媒体和已有结果不会删除。
- 重试只接受 owner 的 `FAILED` workflow，并调用 `JobStateMachine.retry`。第一次调用重新排队；后续重复调用看到
  非失败状态后不再创建新的重试。
- revision `20260907_0010` 为 workflow 增加 `terminal_generation`。只有权威 ingest/analysis Job 从终态进入新一轮
  执行时才递增；每轮终态 Outbox 使用独立唯一键。这样失败通知后的重试成功或再次失败都会推送新结果，同时
  reconciliation 和重复终态投影仍不会制造重复通知。
- Outbox payload 保存该轮终态的状态、错误码、阶段、media ID 和 generation。Dispatcher 渲染历史待发送通知时
  使用这份安全快照，避免重试已开始后把先前失败误画成当前状态。

## 交互文案

- 收集受理仍只承诺“任务已排队”，不承诺完成时间，也不会由 Agent 循环轮询。
- 失败终态通知附带“重试刚才的视频任务”和带 Workflow ID 的文字指令；`retry_collection` 已加入插件 manifest
  和 Feishu 专属 messaging toolset。
- 本阶段不逐条转发 `job.progress`，避免长任务刷屏。实施计划列为第二迭代的飞书交互卡片尚未启用，因此没有
  接受任何客户端 action payload，也不需要 action token。现有文字工具以服务端状态机保证重复操作幂等。

## 验收覆盖

- 无 ID 的最近任务解析严格隔离 chat/thread；显式 ID 按订阅者身份校验。
- 非 owner 不能取消或重试共享 workflow；重复重试只生效一次。
- 重试前后产生不同终态 generation 和 Outbox 唯一键；重试非权威历史 Job 不生成额外终态通知。
- 失败通知提供文字重试指令，且重试中的当前 workflow 不会改写上一轮待发通知的安全快照。
- migration 从阶段 1/3 数据库升级到 head，并可回滚；插件 manifest 与实际注册工具保持同步。
- 完整 `scripts/check.ps1` 通过：181 项 VKC、120 项 Gateway、1 项 Windows 安装检查、Desktop
  typecheck/ESLint 和 29 项 Vitest 均成功。真实 profile 已升级到 `20260907_0010`；Gateway 重启后飞书与
  webhook 在线，并记录一个 active VKC notification dispatcher。当前 profile 没有 workflow 或待投递 Outbox，
  因此未制造任务或向飞书发送测试消息。

阶段 6 继续负责 DNS/重定向 SSRF 防护、入口配额与 B 站错误映射的完整加固。交互卡片可在文字闭环稳定后单独
迭代，并必须使用服务端保存或短期签名的 action token。
