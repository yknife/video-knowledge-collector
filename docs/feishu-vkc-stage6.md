# 飞书 VKC 闭环阶段 6：安全、配额和 B 站可靠性加固

验收日期：2026-09-07。阶段 6 已完成消息入口的安全边界、资源配额、个人数据保留和稳定错误提示。
当前消息采集总开关仍保持关闭，阶段 7 将先对白名单测试用户执行真实飞书 smoke，再决定正式开放。

## URL 与网络边界

- 消息入口只接受 `bilibili.com`、`www.bilibili.com`、`m.bilibili.com` 的点播视频地址和 `b23.tv`
  短链。路径必须是 BV/av 视频路径或短链 token；拒绝用户信息、异常端口、反斜线、空白字符、其他协议和
  相似域名。HTTP 输入在访问前统一升级到 HTTPS。
- Worker 在调用 yt-dlp 前重新执行网络校验。每个 DNS 答案都必须是公网地址；localhost、私网、链路本地、
  保留地址以及公网/私网混合答案均被拒绝。短链最多手动跟随 5 次重定向，每一跳都重新校验 URL 和 DNS，
  且 HTTP 客户端不继承系统代理环境。
- yt-dlp 探测后再次校验平台、最终网页地址和 DNS；消息任务随后只使用该已验证的 B 站正式地址。桌面端已有
  的其他媒体入口不受这一消息专用 allowlist 影响。

## 配额与资源保护

- 默认单用户每天最多提交 10 次、同时活动 1 个 workflow；单聊天每天最多提交 30 次、同时活动 3 个
  workflow。profile 由独立 VKC 数据库天然隔离，消息重放会先命中幂等回执，不重复消耗配额。
- 消息视频默认最长 1800 秒、最高 720p。时长和清晰度继续由 Worker 的权威探测及下载参数执行。
- 新任务受理前检查当前持久化存储根目录至少保留 2 GiB；Worker 下载前再次检查，防止排队期间磁盘空间变化。
  存储根目录解析失败、不可用或余量不足都会安全拒绝，不创建半成品任务，也不删除用户媒体。
- 只有 Gateway ACL 已放行且具备真实用户身份的消息可调用收集工具。Feishu adapter 标记的机器人以及 Gateway
  合成身份会在进入 Agent turn 前被忽略；身份、聊天和话题范围仍完全来自可信 invocation context。

## 保留、脱敏与错误体验

- 用户、聊天、话题和消息 ID 默认保留 90 天。启动时及默认每 24 小时清理一次；只有 workflow 已终止且没有
  `PENDING`、`IN_FLIGHT` 或 `RETRY` Outbox 时才删除订阅及相应旧回执。数据库迁移备份按同一期限清理，清理器
  只匹配活动数据库旁的 `app.db.*.bak`，不处理媒体文件。
- JSON 日志统一遮蔽 Bearer token、API key/secret、Cookies 参数和路径，以及常见签名查询参数；异常堆栈也经过
  同一处理。飞书通知继续只渲染有界结构化数据，对标题和模型内容转义，不返回原始异常、命令、路径或 Cookies。
- yt-dlp 的 412/429 映射为限流，登录要求和 Cookies 过期映射为认证错误，不存在映射为媒体不可用；字幕、ASR、
  Hermes/模型和存储失败保持稳定错误码。用户文案只提供可执行建议，Cookies 提示不包含内容或文件路径。

## 验收覆盖

- URL、短链逐跳重定向、DNS 私网/混合答案、最终探测地址和平台伪造均有回归测试；固定公开 B 站 BV 地址的
  实际 DNS admission 校验通过。
- 用户与聊天的每日/活动配额、低磁盘受理拒绝和 Worker 二次余量检查均有测试；跨用户权限、伪造 origin、
  机器人准入和合成身份拒绝由 Gateway/VKC 集成测试覆盖。
- 个人数据只在终态且 Outbox 排空后清理；prompt 内容保持不可信标记并经过转义；日志凭据、Cookies 路径和
  签名 URL 的泄漏测试通过。
- 完整 `scripts/check.ps1` 通过：205 项 VKC、144 项 Gateway、1 项 Windows 安装检查、Desktop
  typecheck/ESLint 和 29 项 Vitest 均成功。本阶段没有新增 schema revision，数据库 head 仍为
  `20260907_0010`。Gateway 与 Worker 已重启加载新代码；飞书和 webhook 在线，VKC Dispatcher 为 1 个，
  存储可用空间约 1438.7 GiB。当前 workflow 和待投递 Outbox 均为 0，未发送合成测试消息。

阶段 7 将执行测试飞书私聊、群聊 @ 和群话题的真实 B 站短视频闭环，以及断网/重启恢复 smoke；在此之前
`VKC_MESSAGING_INGEST_ENABLED` 保持 `false`。
