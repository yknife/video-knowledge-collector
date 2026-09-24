# Wiki 阶段 5 验收报告

- 状态：已通过（合成样本、真实 Hermes 模型及完整回归）
- 日期：2026-09-24
- 基线：Hermes 子模块 `4e29a74c9a67e71df627044c5c1f2e6610341490`；阶段 5 实现提交为 `64663971ca`。后续飞书摘要修复提交为 `a1a9f79331`。
- 前置：阶段 0—4 已通过。

## 实现

主要新增文件：`plugins/video_knowledge/backend/app/services/wiki_compiler.py`、`plugins/video_knowledge/backend/hermes_client/wiki_agent.py`、`plugins/video_knowledge/backend/migrations/versions/20260924_0014_wiki_fusion.py`、`tests/video_knowledge/wiki/test_fusion.py`、`scripts/wiki_stage_5_smoke.py`（均位于 Hermes 子模块）。主要更新文件：Wiki 入库服务、来源服务、Worker runner/pipeline、入库 API，以及 Desktop 插件的 `api.ts`、`types.ts`、`wiki.tsx`。主仓库更新本报告、实施计划和项目记忆。

`WikiCompiler` 将模型提交的有限变更集编译为主题、实体、对比页面。每项断言引用不可变来源修订、真实 Transcript 片段 ID 与精确时间范围；材料事实、作者观点和推断分别标识。编译器限制页面、断言、别名、标签和关联数量，拒绝路径穿越、危险标记、虚构证据、降级分析的断言、单来源对比以及把同场直播切段当作独立佐证。提交继续使用阶段 1 的 Wiki 发布日志、修订冲突检查与恢复协议；index 和 log 由发布服务维护。

Hermes Wiki 适配器通过原生 slash Skill 加载器调用固定 hash 的 `llm-wiki` 2.1.0，创建绑定当前 Wiki 的独立 Agent 回合。可调用工具仅有读取方向文件、搜索和读取页面、读取来源、提交变更五种；方向文件在其他知识工具前读取。来源和页面内容均作不可信数据，工具使用当前 run 身份校验。每回合最多 24 次 Wiki 工具调用、26 次 Agent 迭代，单次模型输出上限 4096 token，来源和候选页返回有数量与长度上限。审计只记录技能版本/hash、模型、方向文件 hash、工具顺序、调用量、耗时、费用估算和 commit ID，不保存私有 Transcript 或完整提示。

基础入库确认后，独立的低优先级 `WIKI_FUSE` 任务自动排队；已有视频页可通过融合补录 API 与 Desktop 控件补做。降级来源保留来源包与视频页，融合显示需要复核。媒体详情和 Wiki 页面分别显示来源入库与融合状态，概念/实体/对比页引用可继续跳转视频时间。数据库迁移 `20260924_0014` 为 `wiki_ingestions` 增加融合任务、run、commit 三个字段；没有改写既有来源或页面。

## 验收证据

| 要求 | 结果与证据 |
| --- | --- |
| A/B 主题复用、D 不误合并 | 真实模型临时 Wiki 运行生成共用的“索引重建/检索增强”主题页；D 只生成“盆栽浇水”页。独立运行及审计见下文；`scripts/wiki_stage_5_smoke.py` 可复现。 |
| C 冲突与来源 | 真实模型在“索引重建”页保留 A 的全量重建主张、B 的增量主张及 C 的反对/证据不足观点；争议推断同时引用 A/B，页面标记 contested。逐条引用均指向真实来源片段，时间为 10 秒。 |
| 类型、证据和别名 | `test_fusion.py` 验证事实/观点/推断渲染、引用解析、实体与对比页生成、别名冲突、非法路径/片段/关联拒绝。 |
| 降级与独立性 | 测试 E 保留基础页且不排融合任务；L1/L2 同场直播分段不能创建独立来源对比页。 |
| 修订冲突与幂等 | 测试旧 revision 提交受拒；相同输入重复编译为空，已提交但数据库确认丢失时按来源修订和 Skill/编译器指纹恢复 commit。失败任务可重试，基础入库不回退。 |
| Skill 与工具限制 | 测试缺失/禁用和 hash 不一致会明确报错；真实 run 的审计从 `skill_load`、`wiki_read_orientation` 开始，之后才读取来源/页面并调用 `wiki_submit_changes`。 |
| 新来源与补录 | 测试基础入库仅创建一个优先级 250 的融合任务、补录复用同一任务；Worker 测试分别确认基础与融合任务的结果。 |

## 真实模型复核

使用当前 Hermes profile 的 `deepseek-v4.1-flash`（custom provider）及阶段 0 的合成 A/B/C/D 固定样本；运行只写入临时 Wiki。Skill SHA-256：`0229e37c1783fcac5b77cfb3242703666cf4aa472d2ae85b6bd5279756b515b6`，适配版本 `wiki-agent-adapter/0.1.0`，Hermes 基线提交见报告顶部。第一轮 run/commit：A `wr_c9c11fc9fb144ff78c2cbeed9895ca79` / `wc_a543d6f963234ccba540bd21bb7cab5b`；B `wr_97aeefdc1e5742db8688a310f8828742` / `wc_be712e5c99cd412aace29ce289f50914`；C `wr_ee35d98fc161418d9aa1218c982ec09c` / `wc_c08ca664232745b68e2d06e30230cc57`；D `wr_ebef872aa335491c9673823bf66af039` / `wc_3f727d0dab474892b90292355a41a894`。

A/B/C 的“索引重建”页共有四条断言：A 作者主张每次新增资料重建索引（观点，A 10 秒）；A/B 对比断言说明两者立场不同且 B 未比较成本（争议推断，A+B 各 10 秒）；C 作者反对每次全量重建（观点，C 10 秒）；C 认为样本不足以断定增量总更好（观点，C 10 秒）。这些都符合合成 Transcript；模型没有按日期裁决哪一方正确。D 的两条断言仅引用 D 0 秒片段，未出现在 A/B/C 页面。A 与 C 第一次提交各有一次被编译器拒绝的无效变更，模型随后更正并成功提交；这证明校验不会直接发布无效变更。

第二轮 run：A `wr_b7f0a07a63174754a9fefbf083e1c62c`，B `wr_33c46ecbc6874651828d1591512e11d7`，C `wr_de9f096d51d04fad994d1de15358825e`，D `wr_dbf28fb9559d434384268ebcbcafb249`。调用次数分别为 8/8/9/6，耗时分别为 59.687/39.781/57.735/55.610 秒。四次审计的估算费用均为 0.0 美元，custom provider 未提供可靠价格，不能解读为免费。第二轮 A/B 建成单独对比页，C 的信息却只写入通用“检索增强”页，未补进争议对比页；这是模型质量波动，随后已收紧指令并增加自动验收断言。

第三轮 run：A `wr_3fe0496526c643ffaebc83b35cb80678` / `wc_5969fd0c8fd34cf8b13ba13b98aab2d6`；B `wr_bc4f059efb9c4114bc8ffc949e724026` / `wc_40b06209b0544d7c87ff9115facf256c`；C `wr_ab0e98e1fbb14332b3680905aebaebc8` / `wc_d3af1d0c9a95468bbc89b6fa3873a3c3`；D `wr_d6e77768b9ed4e358dfe585ca3f1d9c1`，模型选择不新增融合页。调用次数为 7/6/6/5，耗时为 63.844/76.344/36.235/27.266 秒，provider 仍只给出 0.0 美元的不可靠估算。自动断言确认 A/B/C 同处争议页面，D 未进入 A/B/C 页面。人工逐条核对“索引更新策略对比”页的五条断言：A 的全量重建观点、B 的增量观点、A+B 的相反建议推断、C 的反对与样本不足观点、A+B+C 的未裁决综合推断；所有断言均标争议，分别引用对应来源的 10 秒片段，综合推断引用了所提及的全部三个来源。没有凭新日期裁决胜负。

本地可重复运行的审计摘要保存于 `artifacts/wiki-acceptance/stage-5/real-model-summary.json`（该目录按仓库忽略规则不入 Git；仅包含合成样本）。其中有每次的方向文件 SHA-256、工具顺序、模型、调用次数、耗时和估算费用。provider 价格或账单若未提供，估算费用不能作为实际收费凭据。

## 检查与恢复

- `uv run --project . --extra dev pytest tests/video_knowledge/wiki/test_fusion.py -q`：10 passed。
- 最终 `scripts/check.ps1`：359 VKC、148 Gateway、78 Feishu、1 installer、35 Desktop 测试通过；Python Ruff/format、Desktop typecheck/lint 通过。
- 实际 A/C 模型曾提交无效变更，编译器拒绝后页面完整，第二次受控提交成功。旧 revision 冲突在提交层拒绝；重试从最新页面重新合并。

## 限制

真实模型措辞与建页数量可能随运行变化；可靠性依赖不可变证据校验、页级修订和已处理来源标记。当前验证使用合成样本与临时 Wiki，尚未在用户私人媒体库批量补录。模型调用有次数与输出边界，费用为 Hermes 可获得的估算值，实际账单由 provider 决定。阶段 6 的 query/save 流程不在本阶段范围。
