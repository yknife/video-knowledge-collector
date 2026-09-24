# Wiki 阶段 2 验收报告

- 状态：已通过
- 日期：2026-09-24
- 基线：主仓库 `dd8bf4e`、Hermes 子模块 `d5af2f7699e6e54261e3a78db23f17f44e7fc56f`；本阶段仍为未提交的工作树改动。
- 前置：阶段 0 与阶段 1 已通过。
- 实现：确定性来源快照、四文档版本固定与引用校验、单视频页面、直播场次目录和结构化引用跳转契约。
- 迁移：无。仍复用阶段 1 的 Wiki catalog、commit、projection；自动入库意图和任务属于阶段 3。

## 文件与接口

- `thirdparty/hermes-agent/plugins/video_knowledge/backend/app/services/wiki_source_service.py`：`freeze`、`read_snapshot`、`ingest`、`resolve_citation`。
- `thirdparty/hermes-agent/plugins/video_knowledge/backend/app/services/wiki_storage_service.py`：公开当前 Wiki 修订供受控提交使用。
- `thirdparty/hermes-agent/plugins/video_knowledge/backend/app/schemas/wiki.py`：`WikiCitationTarget`。
- `thirdparty/hermes-agent/tests/video_knowledge/wiki/test_video_sources.py`、`fixtures.json`：阶段 0 固定样本的真实 SQLite 与文件系统验收。
- 本报告、实施计划及项目记忆。

`freeze` 接收明确的四个 KnowledgeDocument ID，拒绝缺失、混版、非 READY 或跨媒体文档。来源包包含 `metadata.json`、`transcript.json`、带片段锚点的 `transcript.md`、`analysis.json` 和 `manifest.json`。`source_revision` 由固定输入及编译器版本的 SHA-256 计算；既有包只校验，不覆盖。`read_snapshot` 可在原媒体文件不可用时读取快照，并重新验证内容指纹与文件哈希。

视频页路径使用稳定 media_id；frontmatter 的 `source_refs` 保留旧来源修订，`generation_metadata` 记录模型、Prompt、四文档 ID、分析与 Transcript 版本、降级状态。结论引用在 `citation_refs` 中保存 source_revision/media_id/transcript_id/segment_ids/start_ms/end_ms；Markdown 链到来源片段锚点。`resolve_citation` 再次验证片段与时间后返回现有播放器路由，阶段 4 接入界面。

## 验收逐项

| 项 | 实际结果与证据 |
| --- | --- |
| 2.1 A 页面 | 样本 A 入库后，来源包四项正文文件与 manifest 齐全；页面摘要、章节、知识点、问答可读。`test_a_snapshot_video_page_citations_and_idempotence`。 |
| 2.2 引用 | 四类条目的引用（含降级范围）必须匹配真实 segment ID 和确切毫秒范围。页面结构化引用数量和原分析一致；虚构片段被拒绝。`test_a_snapshot_video_page_citations_and_idempotence`、`test_e_degraded_and_bad_citation_rejected`。 |
| 2.3 幂等 | A 重复入库返回已有结果；Wiki 修订保持 1、日志仅一条，原来源包经哈希复核后重用。`test_a_snapshot_video_page_citations_and_idempotence`。 |
| 2.4 新版 F | F 与 A 共用稳定 page_id，页面修订从 1 增至 2；A 来源包和旧页面快照仍可读取，跨轮混搭四文档被拒绝。`test_f_updates_stable_page_and_retains_a_source`。 |
| 2.5 降级 E | 页面显示醒目待复核警示、降级范围及结构化证据，标明摘要是来源概述。`test_e_degraded_and_bad_citation_rejected`。 |
| 2.6 直播 L1/L2 | 两段各有视频页、共用稳定场次目录；目录按分段序号排序。引用分别返回自身 media_id、segment ID 与段内 `t=0` 路由，没有推算整场偏移。`test_live_parts_share_session_but_have_local_time_links`。 |

## 检查与限制

- `uv run --project thirdparty/hermes-agent --extra dev pytest thirdparty/hermes-agent/tests/video_knowledge/wiki -q`：10 passed。
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1`：完整通过，含 337 VKC、148 Gateway、78 飞书、1 installer、30 Desktop 测试，以及 Python lint/format、Desktop typecheck/lint。
- 本阶段使用合成数据在真实 SQLite 和临时 Wiki 目录运行；没有调用真实模型，也未在用户现有媒体库执行批量入库。桌面引用组件尚未接入，引用解析服务已返回其现有路由格式。来源包先于页面提交发布；若页面提交失败，未被引用的不可变来源包可在重试时复用，阶段 3 的调度/恢复需识别这一状态。
