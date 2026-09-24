# Wiki 阶段 3 验收报告

- 状态：已通过（临时 SQLite 与合成样本验证）
- 日期：2026-09-24
- 前置：阶段 0—2 已通过；阶段 2 的未提交工作树改动一并保留。
- 迁移：`20260924_0012` 新增 `wiki_ingestions`，不改写既有媒体或分析数据。升级默认 `wiki.auto_ingest=false`。

## 实现

`KnowledgeService._persist` 在四份 READY 分析文档的同一数据库事务中创建唯一 `wiki_ingestions` 记录、独立 `WIKI_INGEST` Job 和 `job.created` 事件。任务在事务提交后即可由现有 Worker 领取；无需分析任务完成回调或进程内队列。桌面和飞书进入同一分析持久化服务，按四份文档 ID 去重。手动和批量补录复用同一记录与任务。Wiki Job 优先级为 150，低于常规采集任务；不归属原采集工作流，Wiki 失败不会重跑或改写分析任务。

Worker 使用原有任务租约与状态机，另持 Wiki 写入租约和 fencing token。先恢复 PREPARED 提交，再冻结来源、发布页面，最后确认 `source_revision` 和 `commit_id`。若页面已提交而确认失败，重试读取已提交页面并补记确认，不产生额外修订或日志。旧版本晚于新版本执行会报告 `WIKI_CONFLICT`，页面保持新版本。

后端接口：

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| GET/PUT | `/api/v1/wiki/settings` | 读取或切换自动入库；开启时初始化 Wiki。关闭仅停止产生新自动任务，已排队任务继续执行。 |
| POST | `/api/v1/wiki/media/{media_id}/ingest` | 以最新完整 READY 四文档手动入库；重复点击返回同一任务。 |
| POST | `/api/v1/wiki/backfill/preview` | 预览媒体库，支持 `media_ids` 筛选，无文件写入。 |
| POST | `/api/v1/wiki/backfill` | 确认补录；仅提交新增、版本更新、待复核项，返回 batch/job IDs。 |
| POST | `/api/v1/wiki/backfill/{batch_id}/cancel` | 取消仍在排队的项、请求运行中任务在安全点取消；已完成页面保留。 |
| GET | `/api/v1/wiki/ingestions` | 查询入库记录，可按 `media_id`、`status` 筛选；返回 Job 状态、Wiki 状态、来源修订和错误码。 |

预览状态含 `NEW`、`SYNCED`、`VERSION_UPDATE`、`NO_ANALYSIS`、`REVIEW`，已有任务另返回 `PENDING`、`PROCESSING`、`FAILED`、`CONFLICT`、`CANCELLED`。失败任务可调用既有 `/api/v1/jobs/{job_id}/retry` 单独重试；再次手动入库同一失败或取消的版本也会复用原 Job 并重新排队。

## 验收证据

| 要求 | 证据 |
| --- | --- |
| 自动入库与默认关闭 | `test_auto_setting_creates_job_in_analysis_transaction` 验证开关、四文档与独立任务同事务；关闭后新分析不创建 Wiki Job。 |
| 进程退出后恢复 | `test_manual_ingestion_survives_restart_and_is_idempotent` 重新构造消费者从持久队列领取任务；`test_bundle_and_job_rollback_together_and_backfill_cancel` 验证事务回滚不留孤立任务。 |
| 去重与版本顺序 | 重复提交返回同一 Job；`test_newer_bundle_published_first_blocks_older_rollback` 验证旧分析不能覆盖新页；现有 `claim_next` 原子领取避免多 Worker 同时执行同一 Job。 |
| 独立失败与重试 | Wiki 使用单独任务类型和结果，原分析工作流不受 Wiki 失败影响；`test_confirmation_failure_retries_without_duplicate_publication` 验证只重试 Wiki。 |
| 补录与取消 | `test_bundle_and_job_rollback_together_and_backfill_cancel` 验证预览、提交和取消；`test_cancel_backfill_preserves_completed_page` 验证已完成页面保留。 |
| 文件与数据库确认边界 | 故障注入在文件提交后抛出异常，重试后仅 1 个 Wiki 修订、1 条可见 commit 日志，并补齐记录的来源修订与提交 ID。 |

定向测试：`pytest tests/video_knowledge/wiki -q`，17 passed（包含从 `20260924_0011` 升级到 `20260924_0012` 的迁移烟测）。完整 `scripts/check.ps1` 通过：344 VKC、148 Gateway、78 Feishu、1 installer、30 Desktop 测试，及 Ruff、格式、typecheck、ESLint。本阶段未触碰用户现有媒体库，也未打开真实自动入库开关；阶段 4 将接入 Desktop 设置、状态、补录和搜索阅读界面。前述桌面与飞书一致性由共用 `KnowledgeService` 路径保证，未执行真实飞书外部消息验收。
