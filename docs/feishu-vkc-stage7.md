# 飞书 VKC 闭环阶段 7：发布验收

验收日期：2026-09-07。自动化门禁、测试 profile 备份、migration、白名单发布、私聊、群聊、群话题、
真实平台失败和 Gateway 重启恢复均已完成。

## 发布配置

- 使用 SQLite online backup 备份了 Hermes `state.db`、VKC `app.db`、Kanban 数据库、`.env`、`config.yaml`
  和 Gateway 状态，并为每个文件记录 SHA-256。备份位于 profile 的 `.curator_backups`，未进入代码仓库。
- VKC migration 已执行到 `20260907_0010`。消息入口已打开，但 Feishu allow-all 保持关闭，allowlist 只包含
  最近已验证的一个私聊测试用户；默认用户/聊天配额、30 分钟、720p 和 2 GiB 存储余量限制继续生效。
- Gateway、Feishu adapter、webhook、Desktop Worker 和唯一 VKC NotificationDispatcher 均在线。当前模型为
  `doubao/deepseek-v4-flash`。

## 已完成的真实 canary

- **私聊成功结果**：使用已有 217 秒公开 B 站视频的 READY 知识缓存创建可信订阅，16 ms 内完成持久化受理；
  终态结果通过真实 Feishu API 回复历史真实入站消息，Outbox 状态为 `DELIVERED`。
- **真实平台限流**：对未缓存的固定公开 BV 地址执行真实 DNS、yt-dlp 和 Worker 流水线。平台持续返回 412，任务
  完成 3 次有界尝试后稳定终止为 `RATE_LIMITED`，安全失败文案已回复私聊，Outbox 为 `DELIVERED`。
- **Gateway 恢复**：停止 Gateway 后创建缓存命中订阅，确认 Outbox 为 `PENDING`；重启后 Feishu 和 webhook
  恢复连接，Dispatcher 在约 10 秒内自动投递并置为 `DELIVERED`，没有创建第二个 workflow。
- **群聊和群话题**：白名单用户在真实测试群 @机器人发送同一固定 BV 链接，并在该消息的话题中再次发送。
  两条独立订阅的失败终态均准确返回原群/原话题，Outbox 为 `DELIVERED`。
- 初次群聊和话题请求暴露了两个问题：模型往返令受理耗时达到 27 秒以上；话题回复锚点曾被误用作工具幂等
  消息 ID，导致话题请求复用群聊任务。Gateway 现在对“采集/收集/分析/知识 + 单个合法 B 站 URL”执行确定性
  快速受理，并分别保存事件自身 ID 和回复锚点。使用两条真实入站事件幂等重放后，群聊和话题从持久化受理到
  Feishu API 确认投递分别为 966 ms 和 646 ms，均复用预期 workflow，没有产生重复任务。
- 最终共有 1 个成功、3 个失败 canary workflow，6 条 Outbox 全部 `DELIVERED`，backlog 为 0。VKC 媒体占用
  约 33.0 GiB，可用空间约 1438.7 GiB。失败任务均来自 B 站匿名访问的真实 412 限流。

## 自动化门禁

`scripts/check.ps1` 现将完整 Feishu adapter 78 项测试纳入固定门禁。本次结果为：206 项 VKC、145 项 Gateway
核心、78 项 Feishu adapter、1 项 Windows 安装检查、Desktop typecheck/ESLint 和 29 项 Vitest 全部通过。
覆盖 URL/SSRF、权限与上下文隔离、workflow、migration、Outbox 退避/恢复、飞书稳定 UUID、网络超时、撤回
目标、机器人拒绝、状态/取消/重试、缓存命中、错误脱敏和存储配额。

## 验收结论

阶段 7 已完成。消息入口保持仅一个已验证用户的 allowlist 发布状态；私聊、群聊和群话题可以发送合法 B 站链接。
当前环境未配置平台 Cookies，未缓存视频仍可能被 B 站 412 限流，但会经过有界重试并把安全失败结果投递回原会话。
