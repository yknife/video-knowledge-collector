# Wiki 阶段 0 验收报告

- 状态：已通过（契约与样本阶段；未实现 Wiki 运行时）
- 日期：2026-09-24
- 主仓库：工作树含用户原有 `docs/project-memory.md` 修改及未跟踪实施计划；本阶段新增文件为下列 ADR、规范、样本、验证器与本报告，并更新计划状态和项目记忆。Hermes 子模块固定提交 `351ebd8e2df78dacb66b693669b0bc58da8e7ee7`，未改子模块。
- 前置阶段：无。
- 实现范围：冻结分析组、入库状态、发布恢复、工具权限、页面/引用、Skill 适配与审计契约；创建八个合成样本及机器可读预期。
- 数据/接口/配置迁移：无。阶段 1 起按 ADR 建新表和存储；阶段 0 未修改真实数据库或启动服务。

## 验收逐项结果

| 编号 | 预期 | 实际与证据 |
| --- | --- | --- |
| 0.1 | A—F、L1/L2 来源、引用与关系机器校验，冲突人工可核 | `docs/wiki-stage-0/fixtures.json` 含 8 Transcript、32 份四类分析文档及预期关系；`scripts/validate-wiki-stage-0.py` 全部通过；八份 `AnalysisBundle` 经现有 Pydantic schema 校验通过。冲突原文与预期见 `docs/wiki-stage-0/fixture-review.md`。 |
| 0.2 | 规范含范围、领域、标签、建页阈值、观点与编辑 | `docs/wiki-stage-0/SCHEMA-example.md` 完整列出；`ADR-001-wiki-contract.md` 补充页面例、版本和权限。 |
| 0.3 | 四个断点边界 | ADR 的“页面与提交协议”列出分析事务、排队、文件发布、索引确认及恢复演练。 |
| 0.4 | 本地根目录、版本、工具和接口明确 | ADR 固定 storage_root 内 Wiki、四表职责、编译指纹、原生加载入口和拟定适配器接口。 |
| 0.5 | Skill 源码位置、最小加载及完整 hash | 见下方加载记录与 ADR 差异清单。加载的是本机 Hermes 可用 Skill，内容 hash 与锁定子模块一致。 |

## 运行记录

1. `python scripts/validate-wiki-stage-0.py` → `8 synthetic samples, 32 analysis documents, citations and relations valid`。
2. `uv run --project . --extra dev python -c ... AnalysisBundle.model_validate(...)`（Hermes 子模块目录）→ `8 AnalysisBundle schema validations passed`。
3. `uv run --project . --extra dev python -c ... skill_view/build_skill_invocation_message ...`（Hermes 子模块目录）→ `skill_view=available slash=/llm-wiki loaded=true`；`build_skill_invocation_message` 的结果包含完整 Skill 标题和正文。
4. 实际加载文件 `C:\Users\37260\AppData\Local\hermes\skills\research\llm-wiki\SKILL.md`，SHA-256 `0229e37c1783fcac5b77cfb3242703666cf4aa472d2ae85b6bd5279756b515b6`；锁定子模块同路径相对文件 hash 相同，声明版本 `2.1.0`。源码：`tools/skills_tool.py::skill_view`，`agent/skill_commands.py::build_skill_invocation_message`、`_load_skill_payload`、`_build_skill_message`。子模块 Skill 目录无附加资源。当前 smoke test 证明本机可发现、启用、加载；尚未执行 Wiki Agent 或真实模型。

## 真实媒体与后续限制

真实模型验证候选媒体 ID：`media_01787149952101868200_0a7461b1a1`、`media_01787235946916857400_c1b4e93686`、`media_01787238250317285100_8042cd1993`。仅从本机现有数据库只读查询 READY 知识文档中的 ID；未复制标题、Transcript 或其他私人内容。阶段 5 前须检查媒体和分析版本是否仍可用，并另选含真实冲突的素材；这些 ID 不保证构成 A/B/C 关系。

本阶段没有运行全量 `scripts/check.ps1`：未改运行时代码。下一阶段需落实页面/文件协议并用故障注入验证；Skill 驱动的 ingest/query/lint 和真实模型质量分别在阶段 5—7 验收。
