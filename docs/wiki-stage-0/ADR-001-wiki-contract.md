# ADR-001：视频 Wiki 契约与发布边界

状态：阶段 0 冻结草案 · 2026-09-24 · 后续阶段如变更须记录 ADR 修订

## 源码核查与决策

| 问题 | 已核实的现状 | 阶段 1—7 契约 |
| --- | --- | --- |
| 分析成组 | `knowledge_service.py::_save_bundle` 在同一 `session.begin()` 中写入 summary、chapters、knowledge_points、suggested_qa 四行；它们共享 media_id、transcript_id、fingerprint，但当前没有显式 group_id。`latest_documents` 按类型取最大 version，可能拼接不同分析轮次。 | 增加显式分析集合标识，旧数据按相同 media_id、transcript_id、fingerprint 且四类 READY 唯一成组；不完整或歧义组不自动入库。固定具体四个 document ID、版本、内容哈希，不再临时查询每类最新。 |
| 事务边界 | `worker/analysis_pipeline.py::run` 在 `analyze` 返回后才调用 `JobStateMachine.complete`；前者写文档与后者完成任务是两个事务。 | `WikiIngestion` 自动意图与四文档同事务写入，或在同事务写持久 outbox；调度器扫描未处理意图。不得依赖任务完成后内存调用。Job 状态仍只通过状态机改变。 |
| 模型能力 | `hermes_client/client.py::generate_json` 支持 Responses JSON schema 和 Chat Completions JSON schema；部分模型降级到 json_object，`KnowledgeService` 再用 Pydantic 与引用校验。 | 这只用于普通分析；Wiki Agent 另建适配器，执行 Hermes 原生 Skill 上下文及受控 Wiki 工具。不得把 `generate_json` 当作 Skill 加载。 |
| 桌面与工具 | Desktop 插件 `plugin.tsx` 注册 `/video-knowledge`；`page.tsx` 读取 `?media=<id>&t=<毫秒>`，`library.tsx` 在媒体 metadata 加载后设置 `currentTime`。后端 `plugins/video_knowledge/__init__.py` 通过 `ctx.register_tool` 注册现有只读聊天工具。 | Wiki 阅读 API 保持 profile 作用域；引用先解析 `source_revision` 与片段，再用该路由跳转。新增工具从插件注册，但工具处理器须执行真实路径和权限限制。媒体不存在时只显示文本。 |
| 进程 | `app/integration/runtime.py::WorkerSupervisor` 用独立子进程运行 Worker，断开后重启；Gateway 与 Desktop 也可各自存活。 | 不用共享进程全局 `WIKI_PATH` 切换 Wiki。每次 Agent 运行绑定 wiki_id、profile、root，Worker 和 Gateway 均通过数据库及工具权限协调。 |

## 文件、数据库与迁移

默认根目录为当前 profile 的已配置 `storage_root/wiki/`，根目录持久化随机 `wiki_id`。配置路径必须解析后仍位于 storage_root；拒绝符号链接或 junction 越界。Markdown 文件是已发布正文的权威来源；数据库索引和反向链接是可重建投影，不能代替正文。`raw/videos/<media_id>/<source_revision>/` 不可变；`notes/` 从不由自动编译器覆盖。路径使用稳定 ID，中文标题只写入元数据。

迁移从下一数据库 revision 新建下表，升级默认不启动历史补录，不修改现有媒体、Transcript、KnowledgeDocument 行；先创建表和唯一约束，再加入调度与读取。回滚代码不得删除已发布 Wiki 文件。

| 表/对象 | 权威职责与关键字段 | 唯一性/恢复 |
| --- | --- | --- |
| `WikiSourceRevision` | 固定 wiki_id、media_id、transcript_id、四个 knowledge_document_ids/versions/hash、schema/compiler/skill 指纹，记录 raw manifest 路径与状态。 | `source_revision` 为内容寻址 ID；同一输入重复只指向同一快照。快照成功写入后不可覆盖。 |
| `WikiIngestion` | 持久意图、触发来源、输入版本、状态（PENDING/PROCESSING/BASE_READY/FUSION_PENDING/SUCCEEDED/FAILED/CONFLICT/REVIEW_REQUIRED）、重试、租约、fencing token、结果 ID。 | `(wiki_id, ingestion_key)` 唯一。基础页成功与融合成功分别记状态。Worker 写入必须持有有效租约。 |
| `WikiPageProjection` | page_id、type、path、当前已提交 revision/hash、标题、标签、索引文本、反向链接、证据映射。 | 从提交 manifest 和已提交 Markdown 重建；不可充当正文唯一来源。 |
| `WikiCommit` | commit_id、wiki_id、base revision、目标 revision、文件旧/新 hash、阶段、manifest、确认时间。 | 同一 commit_id 只能确认一次；发布后数据库确认失败，重试确认而不重跑模型。 |

入库键计算为 `SHA-256(canonical JSON{wiki_id,media_id,transcript_id,sorted four document IDs/versions/hashes,schema_version,compiler_version,skill_sha256})`。阶段 1—4 的基础页操作可用固定 `skill_sha256=null`，阶段 5 融合将 Skill hash 纳入独立编译指纹。新分析迟到时，以媒体当前已发布的来源序号/分析版本比较，不允许旧版本回退；旧快照保留可读。

## 页面与提交协议

页面 frontmatter 和结构化引用以 `SCHEMA-example.md` 为准。页面稳定 `page_id` 不随标题变；所有链接用标准相对 Markdown 链接。结论必须指向本来源 Transcript 的真实 segment_ids 和覆盖时间范围；来源概述可无结论级引用，但须标明。跨来源观点并列记录，模型置信度只是提示，不代表事实验证。直播片段的时间默认分段内毫秒，只有可靠场次偏移才显示整场时间。

提交前验证允许的目录、扩展名、路径规范化与解析后的 storage_root 边界，页面类型、标签、frontmatter、引用、base revision、原文件 hash 和 Worker fencing token。模型只能提出变更集，不能直接写目录。每个 Wiki 串行提交；模型可在锁外生成，锁内重查版本并提交。`index.md`、`log.md`、页面和 manifest 使用同一 commit_id。

发布顺序：写 `_meta/staging/<commit_id>` 与旧/新文件清单并 fsync → 数据库记 PREPARED → 获取带 fencing token 的 Wiki 提交租约 → 检查 revision/hash → 逐文件发布并记录可恢复进度 → 写已提交标记 → 数据库记 COMMITTED 并更新投影。读取器只读取 COMMITTED 版本；启动先扫描 PREPARED/发布中记录，按 manifest 全部完成或回滚，再开放 Wiki 读写。索引更新失败可按 commit_id 重建确认。外部编辑器在多文件替换期间可能短暂看到中间状态，用户文档须说明。

断点演练：①四文档事务提交前失败不得出现自动意图；提交后进程退出仍能扫描到意图。②入库排队后退出，重启扫描同一 ingestion_key，不能重复发布。③逐文件发布中退出，恢复后读者只见完整旧版或新版。④文件提交后索引/数据库确认失败，重启按 commit_id 补确认，日志仅一条。过期租约的旧 fencing token 在每次写入前拒绝。

## Skill 绑定与权限

锁定 Hermes 子模块 `351ebd8e2df78dacb66b693669b0bc58da8e7ee7`，`skills/research/llm-wiki/SKILL.md` 声明版本 2.1.0，文件 SHA-256 `0229e37c1783fcac5b77cfb3242703666cf4aa472d2ae85b6bd5279756b515b6`。该目录没有额外 references 文件。上游加载入口是 `tools/skills_tool.py::skill_view`，斜杠执行经过 `agent/skill_commands.py::build_skill_invocation_message` → `_load_skill_payload` → `skill_view(..., preprocess=False)` → `_build_skill_message`，完整内容进入模型消息。`ctx.register_tool` 是现有插件工具入口。阶段 5 实现新 Wiki Agent 执行上下文时必须复用这条原生加载路径或 Hermes 等价原生入口；目前没有已确认的 HTTP Skill 参数或 VKC 专用 Agent SDK。

拟定适配器版本 `wiki-agent-adapter/0.1.0`，接口 `WikiAgentAdapter.run(operation, wiki_context, source_revisions, budgets, tool_policy) -> WikiAgentRun`，实现放在 `backend/hermes_client/`。调用前验证实际加载路径、启用状态、固定 hash；加载失败返回明确错误，绝不退化为自定义 Prompt。每次操作先经受控工具读取 SCHEMA、index、近期 log，再读相关页/来源。上下文绑定 root，而不修改共享环境变量。`query` 默认只读；用户明确保存后才获取写权限。`ingest`/`lint` 写入只能提交受限变更集。任何自动写入用户 `notes/`、`raw/` 或任意 Wiki 根外路径都由工具拒绝。

审计记录由加载及工具调用事件生成：run_id、operation、wiki_id/profile、Skill 名称/版本/hash、Hermes commit、适配器版本、模型、SCHEMA/index/log 的读取 revision/hash、读取顺序、工具名称与结果状态、输入 source_revision、输出 commit/report ID；只记录脱敏路径和标识，不存私人全文、密钥或 signed URL。Skill 升级须更新 hash 和差异清单，回归 ingest/query/lint，旧页面不自动重写。

## 上游 Skill 差异清单

| 上游 2.1.0 约定 | VKC 覆盖规则 |
| --- | --- |
| `WIKI_PATH` 或默认 `~/wiki` | 使用运行上下文中的 profile/wiki_id/root；不回落全局 Wiki。 |
| `[[wikilinks]]` 与至少两个链接 | 标准相对 Markdown 链接；单来源页允许没有两个相关页，禁止凑链接。 |
| `raw/articles` 等与正文 frontmatter hash | 视频来源放 `raw/videos/...`，JSON manifest 校验所有文件；历史快照不可覆盖。 |
| 通用 `sources` 引用及 provenance 文本标记 | 结论级结构化引用含 source_revision、media_id、transcript_id、segment_ids、start/end_ms；受控工具核验。 |
| 新来源通常覆盖旧来源 | 冲突先并列保留并标记争议；日期不能自动裁定。 |
| 有价值的 query 可自动归档并追加 log | 普通 query 只读；用户明确保存才写入，并记录原 query run_id。 |
| 自由文件写入、索引和日志由 Agent 更新 | Agent 提议受限变更集，应用统一提交 index/log/页面；用户 notes 受保护。 |
| lint 可改文件、旋转日志 | 默认报告；修复另经版本校验提交。 |

这些覆盖规则在 Skill 完整加载后作为 VKC 执行策略和 SCHEMA 注入；通过工具权限强制，而非仅依靠指令。阶段 5—7 须以真实 run_id 验证执行顺序。
