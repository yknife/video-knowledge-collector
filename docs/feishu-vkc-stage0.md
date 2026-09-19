# 飞书 VKC 阶段 0：契约与基线

验收日期：2026-09-06。阶段 0 已完成；消息采集默认关闭，三个写入/工作流工具尚未注册。

## 命令契约

| 工具 | 模型可见参数 | 语义 |
|---|---|---|
| `collect_video` | `url` | 只接收一个 B 站普通视频或 b23.tv 短链；强制自动分析，持久化受理后立即返回 workflow/job ID，不等待下载或分析 |
| `get_collection_status` | `workflow_id` | 从数据库查询调用者有权查看的工作流和权威任务状态；不得返回原始工具错误、凭据或文件路径 |
| `cancel_collection` | `workflow_id` | 仅原请求者或明确授权的管理员可取消；通过 JobStateMachine 请求取消，重复取消幂等，不能删除媒体 |

参数模型：`plugins/video_knowledge/backend/app/schemas/messaging.py`。所有模型禁止额外字段；
平台、profile、session、chat/thread/message/user ID、授权结果必须由 Gateway 可信上下文提供。
Cookies 路径、回调地址、系统提示、`force` 和关闭自动分析等选项不接受模型传入。

URL 契约目前只做词法校验：HTTP(S)、标准端口、无用户凭据，B 站 `/video/BV...` 或 `/video/av...`
以及 b23.tv 短链。拒绝直播地址、番剧/合集入口、伪造域名和本地路径。此校验**不是完整 SSRF 防护**；
入口正式启用前还必须完成 DNS、重定向后目标、权威媒体类型与时长校验。

同一可信 profile/platform/message ID 的重复提交应复用同一工作流；不得由模型提供幂等键。
未授权查询统一返回不可访问，不泄露工作流是否存在。任务中断、失败、降级分析和完整成功必须区分。
完成收集不等于分析完成；终态异步通知属于后续 Outbox 阶段。

## 运维配置

配置沿用现有 VKC `Settings` / `VKC_*` 环境变量来源，示例在 backend/.env.example。
这些限制只用于消息采集，不改变 Desktop 的采集设置。阶段 0 只定义配置和契约，配额执行由后续准入服务负责。

| 配置 | 默认 | 有效范围 |
|---|---|---|
| `VKC_MESSAGING_INGEST_ENABLED` | `false` | bool；关闭时禁止新消息采集 |
| `VKC_MESSAGING_ALLOWED_PLATFORMS` | `["feishu"]` | JSON 数组；空数组拒绝全部，目前只允许 feishu |
| `VKC_MESSAGING_MAX_ACTIVE_PER_USER` | `1` | 1–10，按 profile/user 计算 |
| `VKC_MESSAGING_MAX_SUBMISSIONS_PER_USER_PER_DAY` | `10` | 1–1000；UTC 自然日，幂等重放不重复计数 |
| `VKC_MESSAGING_MAX_VIDEO_DURATION_SECONDS` | `0` | 0 表示不限时长；正数 1–86400 表示启用上限 |
| `VKC_MESSAGING_MAX_VIDEO_HEIGHT` | `720` | 360 / 480 / 720 / 1080 |

准备或修改配置后需重启对应 profile 的 Hermes。关闭入口不应停止现有 Desktop 任务，未来也不能中断
已受理工作流的查询、取消或通知排空。阶段 0 即使把开关设为 true，也不会注册尚未实现的新工具。

## 基线与复现

- 固定公开短视频候选：`https://www.bilibili.com/video/BV1GJ411x7h7/`。
  本机通过 `YtDlpAdapter.probe` 只探测元数据、不下载，结果为 `RATE_LIMITED`；网页读取同样返回 412。
  因此本阶段没有声称真实 B 站闭环已通过。后续 smoke 前需解决当前网络/平台风控条件，不能绕过校验。
- 模拟飞书入站用例：`tests/gateway/test_feishu.py::TestAdapterBehavior::test_process_inbound_message_uses_event_sender_identity_only`。
  输入为模拟私聊 `hello`，使用真实 FeishuAdapter 解析并以 AsyncMock 接管内部 dispatch；验证发送者取自
  平台事件、普通文本正常分发，未连接飞书、未发送真实消息。发送/回复/群门控由该文件其他测试覆盖。
- Desktop 基线：`tests/video_knowledge/api/test_integration_controller.py` 通过实际 transport-neutral
  Controller 和临时数据库受理 Desktop 采集；媒体探测用确定性适配器替身。Desktop `api.test.ts` 验证
  probe/ingest 继续使用原插件 REST 路由。
- 修复了飞书测试的 Windows 环境依赖：清空环境后仍使用临时 profile；DNS rebinding 用例禁止读取本机
  注册表代理，保证测试实际覆盖直连 DNS。生产飞书适配器未改动。
- 开关 false/true 两种配置均验证 manifest 的 provides_tools 与实际注册工具集合一致；本阶段仅五个只读工具。
- VKC 原有 112 项 Python 测试通过；新增契约 37 项、只读工具注册新增参数化用例通过。
  飞书 76 项与 bot admission 14 项通过；Desktop VKC 27 项、Desktop typecheck、VKC Ruff/格式检查通过。

## 后续门槛

阶段 1 实现可信上下文和工具 handler；阶段 2–4 完成持久化关联、Outbox 和投递后才具备完整闭环。
阶段 6 的 DNS/重定向/配额防绕过验证必须在真实对外启用前完成。当前本机采集开关未开启，未改飞书凭据或 ACL。
