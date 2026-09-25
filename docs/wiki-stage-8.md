# Wiki 阶段 8 验收报告

- 状态：待验收。历史补录、备份恢复、故障演练、性能与真实 Skill 三链路均通过；同一媒体的真实桌面播放器点击尚未观察，不能按计划将整阶段标为「已通过」。
- 日期：2026-09-25。
- 实施基线：主仓库 `a69290d`，Hermes 子模块 `15cfad6ddc`；本阶段与上一轮 Wiki 融合修复均为未提交工作区 diff。
- 前置阶段：阶段 0—7 已通过；上一轮 `WIKI_AGENT_INCOMPLETE` 修复已在真实任务上重试成功。

## 实现范围

新增 `wiki_stage8_ops.py` 与运维 CLI：对现有分析做只读 dry-run，按范围/上限/间隔提交补录，通过 batch ID 查询逐项基础入库、融合状态与提交 ID；SQLite backup API 与 Wiki fencing 租约共同生成一致性备份，SHA-256 清单校验后恢复到新目录，明确提示原媒体未包含。新增 `docs/wiki-operations.md`，涵盖开关、补录、失败、争议、人工编辑、撤回、备份和模型费用。没有数据库迁移或新 API。

1,000 页基准发现页面读取每次扫描全部页面，搜索读取命中页时逐条查询。页面链接关系现按 Wiki ID、路径与修订缓存，搜索一次批量读取命中页的已确认快照；修订变化后缓存自动失效。模型超时现在有可重试的 `WIKI_AGENT_TIMEOUT` 错误和审计码。已有未提交的融合修复保持在同一工作区。

## 验收结果

| 计划项目 | 结果与证据 |
| --- | --- |
| 1. 本地媒体完整闭环 | **部分通过**：真实自动入库媒体具备 READY Transcript、四份分析、成功的自动来源页与主题融合提交；在恢复副本上真实 query 返回 5 条引用，其中包含该媒体；引用可解析成 `/video-knowledge?media=...&t=...` 时间路由。桌面播放器中的真实点击尚待人工操作确认。证据：`artifacts/wiki-acceptance/stage-8/auto-loop-evidence.json`。 |
| 2. 历史补录 | **通过**：现有分析中选择 10 个普通视频和同一直播的 4 个分段，dry-run 后限速入队；14 个 `WIKI_INGEST` 与 14 个 `WIKI_FUSE` 均成功，14 份来源快照可核验。无固定样本补足真实数量。证据：`backfill-report.json`、`batch-status-cli.json`、`backfill-final.json`。 |
| 3. 不重做分析与幂等 | **通过**：工具只读取既有四份分析与 Transcript；重复补录同一 14 项新增任务数为 0，Wiki 修订保持 58。证据：`repeat-backfill.json`。 |
| 4. 故障恢复 | **通过**：测试注入模型超时、ENOSPC、索引写入失败、发布中断与旧租约，验证错误可诊断、重试/恢复后已提交内容保留；提交冲突由修订检查拒绝。详见 `test_stage8_ops.py` 与已有 `test_storage.py`。 |
| 5. 并发与一致性 | **通过**：两个基于同一修订的融合变更集，第二个被拒绝后重新编译并提交，A/B 主张均保留。真实库 14 项完成后 `PRAGMA integrity_check=ok`，已确认快照均可读取；结构巡检仅报告 19 个孤立页候选和 3 个未解决争议候选，无索引/来源缺失错误。 |
| 6. 1,000 页性能 | **通过**：Windows 11 Pro、Core Ultra 7 265K、31.3 GB RAM、Predator SSD GM7000 2TB，Python 3.11.15；隔离 Wiki 1,000 页，5 次预热后各 30 次串行服务请求。200 命中的 `Knowledge` 查询 p95 **327.22 ms**，页面读取 p95 **8.5 ms**，不含模型与播放器。证据：`performance.json`。 |
| 7. 备份恢复 | **通过**：真实 Wiki 修订 58 的数据库与 829 个文件在租约内备份，恢复至全新测试目录；SQLite 完整性检查 ok，72 页可读，搜索重建 72 页，原始来源和时间引用可解析，恢复副本可立即取得新租约。CLI 明示原媒体未包含。证据：`live-backup-final/manifest.json`、`restore-final-verification.json`。 |
| 8. 原有功能回归 | **通过代码回归**：`scripts/check.ps1` 完整通过，覆盖采集、直播、转写、分析、飞书与桌面入口的现有测试；未重新触发所有外部平台的真实采集或通知。 |
| 9. 使用文档 | **通过**：`docs/wiki-operations.md` 包含计划列出的操作与费用说明。 |
| 10. 固定 Skill 三链路 | **通过**：真实 ingest `wr_aebd428730f542d1b97f84742857e07f`、query `wq_49650f6311fb4598afe3380015a7b840`、lint `wl_28b15daf83644dc79b8e2956e3b696a2` 均加载 `llm-wiki` 2.1.0 / SHA-256 `0229e37c1783fcac5b77cfb3242703666cf4aa472d2ae85b6bd5279756b515b6`，读取 SCHEMA/index/log 后调用各自页面/证据工具并产生 commit、答案和巡检报告；审计在 `skill-chain.json`。缺失、禁用、哈希不符的 Skill 测试验证不会静默退化，升级步骤已写入运维文档。 |

上述 `artifacts/wiki-acceptance/stage-8/` 是本机忽略目录，包含私人 Wiki 副本和审计，不进入 Git。真实 query/lint 在恢复副本运行；真实 ingest 为正式 Wiki 的补录任务。三个回合使用当前 Hermes profile 的 `deepseek-v4.1-flash/custom`，适配器版本 `wiki-agent-adapter/0.1.0`，API 调用次数分别为 6、20、9；均记录方向文件哈希。自定义 provider 返回的费用估算均为 0.0 美元，不代表实际账单费用。

## 检查与遗留

- `scripts/check.ps1`：382 个 VKC Python 测试、Gateway、飞书、安装器、Desktop 类型/ESLint、38 个 Vitest 与 Ruff 均通过。
- 定向测试：`tests/video_knowledge/wiki/test_stage8_ops.py` 覆盖 dry-run/重复、状态、备份校验/恢复、锁冲突、超时、磁盘故障、索引故障、缓存失效和并发融合。
- 待验收：在当前 Hermes Desktop 打开上述自动入库媒体的 Wiki 页，点击一条时间引用，确认播放器确实跳到对应毫秒位置。此项需要可观察的真实桌面交互；仅有 API 路由与组件测试不足以替代该证据。
