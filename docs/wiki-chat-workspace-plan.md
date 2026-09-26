# Wiki 提问迁移到 Hermes Chat Workspace

日期：2026-09-26。状态：已实现，待真实 Desktop 闭环观察。本文件保留实施与验收依据。

## 目标与范围

知识库页面移除提问输入框、内嵌答案和“保存到知识库”操作，保留“向知识库提问”按钮。搜索框、阅读及维护功能保留。

点击按钮打开 Hermes Chat Workspace 的新会话，实际工作目录为 `D:\vkc\storage\wiki`，默认加载 `llm-wiki`。用户在 Chat 输入问题并连续追问；每轮由模型决定是否将有价值的回答保存到知识库，保存使用已有受控变更流程，无需再点击保存。

首版将“更新知识库”落在现有研究问答页的新增或更新上，复用 `WikiQueryService.save`；不扩展为任意修改概念页、批量重写或删除知识。来源不足、内容重复、没有沉淀价值时可以只回答，不产生 Wiki 修订。后续如需自动修订概念页，再接入已有编译器，不在本轮同时扩展。

## 已核实的基础

以下路径均相对于 `thirdparty/hermes-agent/`：

| 位置 | 现状与用途 |
| --- | --- |
| `apps/desktop/src/plugins/video-knowledge/wiki.tsx` | 当前 `question`、`askAction`、`saveAnswerAction` 及内嵌问答 UI 的移除点 |
| `apps/desktop/src/plugins/video-knowledge/chat-context.tsx`、`plugin.tsx` | 已有聊天上下文、提示条和发送中间件，可扩展 Wiki 场景；现有媒体场景是只读限制，不可直接套用 |
| `apps/desktop/src/sdk/index.ts` | `host.newChat(profile?)` 目前只接收 profile，不能假设已支持目录和技能参数 |
| `apps/desktop/src/app/contrib/wiring.tsx`、`store/session.ts` | 已有 `startSessionInWorkspace` 和会话目录管理，可复用；裸新会话默认不绑定目录 |
| `plugins/video_knowledge/__init__.py`、`tools.py` | 普通聊天目前注册媒体/知识只读工具，尚未注册 Wiki 问答及保存工具 |
| `plugins/video_knowledge/backend/app/services/wiki_query_service.py` | `ask(question)` 调用受控 Wiki Agent；`save(run_id)` 校验审计、来源和引用，幂等发布研究问答页 |
| `plugins/video_knowledge/backend/hermes_client/wiki_query.py`、`wiki_agent.py` | 已有实际 `llm-wiki` 加载与固定哈希校验，复用而非复制问答引擎 |
| `plugins/video_knowledge/backend/app/services/wiki_storage_service.py` | 已有租约、修订、提交日志和恢复协议，继续作为唯一发布入口 |

## 实施步骤

### 1. 入口与会话绑定

- 移除 Wiki 页面问答区及其专用状态，保留按钮，文案说明将在 Hermes 中提问。
- 从当前 profile 的 VKC 后端取得已解析的 Wiki 根目录和 `wiki_id`，当前机器应为 `D:\vkc\storage\wiki`；不要把机器路径硬编码在前端。优先扩展已有 Wiki 响应，确实不足再补一个小接口。涉及 API 时同步 Desktop 控制器、FastAPI 和客户端类型。
- 复用已有工作目录会话创建逻辑，通过 SDK 暴露最小的目录绑定能力，保持原 `newChat(profile?)` 调用兼容。工作目录必须进入真实会话及后端执行上下文，不能只写进提示词。
- 新会话展示 Wiki 目录与 `llm-wiki` 状态，聚焦 Chat 输入框。点击按钮本身不发起模型请求或知识写入。
- Wiki 上下文绑定到目标草稿/会话；发送失败可重试，连续追问及恢复会话仍保留绑定。切换到其他会话不能携带遗留 Wiki 上下文，也不能覆盖已有会话的目录或草稿。

### 2. 技能与受控变更闭环

- 复用 Hermes 原生技能加载机制，在首次提问时实际加载 `llm-wiki`；不以提示词中的技能名称冒充加载。延续现有版本/哈希约束，技能不可用时明确报错。
- 在 VKC 插件增加最小聊天工具桥接：Wiki 问答工具调用 `WikiQueryService.ask(question)`；Wiki 保存工具调用 `WikiQueryService.save(run_id)`。复用服务和现有 API，不再实现一套检索、证据校验或提交协议。
- Chat Agent 接收问答工具返回的答案、引用和 `run_id`，判断是否值得沉淀：需要则调用保存工具，否则直接回答。保存成功后才显示“已更新知识库”；失败保留答案并说明未保存。连续追问交给现有聊天模型整理成完整问题后调用问答工具。
- 更新决策遵循技能与 Wiki 规范：证据充分、有复用价值且有新增内容时保存；重复内容和证据不足不强制保存。模型可判断“不更新”，不要将每次提问无条件转换为保存。
- 工具侧从可信 profile/会话上下文确定 Wiki，校验 run 的归属；不让模型任意指定文件系统路径或保存其他会话的 run。需要的关联元数据复用现有 run/audit 存储，不新建数据库表。
- Wiki 聊天的工具配置在会话开始时确定：知识写入只允许受控工具，不开放可以绕过提交服务改写 Wiki 的通用文件/终端写入能力。目录绑定并不等于写入控制，不能仅靠提示词禁止直写。复用现有工具配置/白名单机制，避免新增通用权限框架。
- 保留当前引用校验、幂等提交和冲突处理。普通读取/模型思考期间不占写租约；保存由已有服务短时持有租约。冲突时明确返回，不静默覆盖，不把未提交结果标成成功。
- 保存结果提供知识页标识、修订或链接；返回知识库时刷新列表、搜索及当前页，复用现有查询失效或重新加载机制。

### 3. 验证与交付

至少覆盖以下行为：

1. 页面无提问输入框，搜索仍可用；按钮进入新 Chat，前端和后端会话目录均正确。
2. 首次请求有真实 `llm-wiki` 加载证据；追问、会话切换及恢复时绑定正确，无上下文串用。
3. “只回答”不改变 Wiki 修订；“值得保存”通过已有服务产生可检索、有引用的研究问答页；同一 run 重试不重复提交。
4. 来源不足、技能缺失、目录不可用、提交冲突及跨会话 run 均有明确结果；失败不伪装成功。
5. Wiki 会话无法经通用工具直接写文件；原单视频/选中视频的只读问答保持正常。

先跑相关 Desktop 与 Python 定向测试、类型检查及 lint；完成后执行根仓库 `scripts/check.ps1`。用隔离 Wiki/数据库副本做一次真实 Desktop → 技能 → 回答 → 模型决定保存 → Wiki 可见的闭环验证，同时验证一次不保存分支。不要用用户真实库做试写。

交付时更新 `docs/project-memory.md`，记录改动文件、测试结果和剩余限制。旧 query/save 后端接口本轮保留，去除页面入口即可，不顺带清理历史数据或重构 Wiki 架构。

## 后续模型执行提示

先读根目录 `AGENTS.md` 与 `docs/project-memory.md`，再按本文件三步实现。优先核实 SDK 的目录绑定、技能加载和会话工具配置真实路径；上述能力的衔接是主要实现风险。首版接受已有 Chat Agent 调用受控 Wiki Agent 的链路与延迟，不为消除这一层调用重写 Agent。所有阶段完成后再交付，不能只做按钮跳转即宣称需求完成。
