# Wiki 阶段 1 验收报告

- 状态：已通过
- 日期：2026-09-24
- 版本基线：主仓库 `ba5a05d`；Hermes 子模块从 `351ebd8e2df78dacb66b693669b0bc58da8e7ee7` 更新到 `d5af2f7699e6e54261e3a78db23f17f44e7fc56f`（`vkc-integration`）。
- 前置阶段：阶段 0 已通过。
- 实现范围：Wiki 初始化、页面读取与列举、路径/frontmatter/链接校验、版本化提交、租约 fencing、文件快照与崩溃恢复。
- 迁移：新增 Alembic `20260924_0011`，建 `wiki_catalogs`、`wiki_commits`、`wiki_page_projections`。现有媒体/分析/任务表未改；`WikiSourceRevision` 与 `WikiIngestion` 按计划在后续来源导出和自动入库阶段接入。

## 变更文件

- `thirdparty/hermes-agent/plugins/video_knowledge/backend/app/services/wiki_storage_service.py`
- `thirdparty/hermes-agent/plugins/video_knowledge/backend/app/schemas/wiki.py`
- `thirdparty/hermes-agent/plugins/video_knowledge/backend/app/infrastructure/db/base.py`
- `thirdparty/hermes-agent/plugins/video_knowledge/backend/migrations/versions/20260924_0011_wiki_storage.py`
- `thirdparty/hermes-agent/tests/video_knowledge/wiki/test_storage.py`
- 本报告、`docs/project-memory.md` 和实施计划状态。

## 验收逐项

| 项 | 结果与证据 |
| --- | --- |
| 1.1 初始化 | 临时存储根中初始化产生 SCHEMA/index/log 和稳定 wiki_id；重复初始化保留 `notes/user.md`；未知非空目录被拒绝且原文件保留。`test_init_is_idempotent_and_refuses_unknown_nonempty_root`。 |
| 1.2 标题与路径 | 两个同名标题使用不同 page_id/path；超长中文标题经过真实提交和读取；Windows 盘符/绝对/父目录越界链接被拒绝；Windows junction 指向存储根外时写入被拒绝。`test_commit_pages_and_snapshot_revision`、`test_rejects_unsafe_paths_links_and_external_edits`、`test_rejects_link_or_junction_escape`、`test_interrupted_update_reads_old_snapshot_then_new`。 |
| 1.3 一致提交 | 两页提交后 page revision/hash、index、log、manifest 具有同一 commit_id；新修订增加且旧快照保留。数据库 `(wiki_id, base_revision)` 唯一约束阻止同一基础修订双提交。`test_commit_pages_and_snapshot_revision`。 |
| 1.4 中断恢复 | 第一次及第二次发布中注入 `os.replace` 故障；DB 仍只展示旧投影和提交快照。新租约 `recover` 后返回完整新版，日志每个 commit_id 仅一条。`test_recovery_and_expired_fence`、`test_interrupted_update_reads_old_snapshot_then_new`。 |
| 1.5 过期 Worker | 使旧租约过期并由新 Worker 领取更高 fencing token，旧 token 提交被拒绝。`test_recovery_and_expired_fence`。 |

## 命令与结果

- `uv run --project thirdparty/hermes-agent --extra dev pytest thirdparty/hermes-agent/tests/video_knowledge/wiki -q`：6 passed。
- 临时 SQLite 上执行 Alembic `upgrade head`：最终 revision `20260924_0011`，三张 Wiki 表存在。
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1`：完整通过，含 333 VKC、148 Gateway、78 Feishu、1 installer、30 desktop 测试及 Python lint/format、桌面 typecheck/lint。Windows 当前策略禁用直接运行 `.ps1`，因此用进程级 ExecutionPolicy Bypass 执行原脚本。
- 完整检查后对初始版本读取和外部编辑检查做了小幅修正；Wiki 定向测试与针对文件的 Ruff check/format 再次通过。

## 故障与限制

测试仅使用临时数据库和目录；未将 Wiki 自动接入运行中的 Desktop 或 Worker，也未执行真实媒体导出。阶段 2 需使用此提交服务创建不可变来源快照与视频页。外部编辑器直接观察 Markdown 文件时，可能在多文件替换期间短暂看到中间状态；应用读取器从已确认快照读取，保持完整旧版或新版。若人工改动已发布页面、index 或 log，自动提交报告冲突，不覆盖用户内容。
