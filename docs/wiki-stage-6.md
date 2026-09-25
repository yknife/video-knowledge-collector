# Wiki 阶段 6 验收报告

- 状态：已通过（临时 Wiki 上的真实 Hermes query、合成样本和完整回归）
- 日期：2026-09-25
- 前置：阶段 0—5 已通过；本次同时保留并验证此前未提交的桌面 Wiki 路由修复。

## 实现

新增 `WikiQueryAdapter`，以 Hermes 原生 slash Skill 加载器加载固定 SHA-256 的 `llm-wiki` 2.1.0，在当前 profile 的 Wiki 中执行独立问答回合。模型只能调用方向文件读取、Wiki 搜索、已提交页面读取、原始 Transcript 片段读取和结构化答案提交五种工具。工具绑定当前 run 身份；回答前必须读取 `SCHEMA.md`、index 和近期 log，且至少检索一次。证据必须来自本次已读页面的 `citation_refs` 和已读原始片段，页面修订、来源修订、媒体、Transcript、片段 ID 与毫秒范围均校验。已保存的 query 页可供检索和阅读，但不能作为新的独立证据。

问答默认只在当前 profile 的 `storage_root/wiki-query-runs/{wiki_id}/` 写入私有 query run 结果及无原文的审计记录，不修改 Wiki 目录或发布页面。审计保存答案哈希，保存时会拒绝被改动的运行结果。桌面“保存到知识库”调用独立接口；`WikiQueryService` 重新校验当前 Wiki 身份、锁定 Skill hash、原始来源和页面引用，再以固定问题 ID 发布 `queries/` 页面。页面 frontmatter 记录原始 query run_id、所读页面修订和证据引用。重复保存相同答案不增加修订，后续搜索与引用回看复用阶段 4 的服务。问答和保存均已接入 FastAPI、Hermes Desktop 控制器、客户端类型和知识库界面。

## 10 题真实模型复核

使用当前 Hermes profile 的 `deepseek-v4.1-flash`，只在临时 Wiki 导入阶段 0 的 A/B/C/D 合成视频，未修改私人媒体库。完整首轮结果在 `artifacts/wiki-acceptance/stage-6/real-query-summary.json`；证据不足题的最终复核在同目录 `real-query-summary-9-10.json` 和 `real-query-summary-9-9.json`（本地忽略，不入 Git）。自定义 provider 只报告 0.0 美元估算值，不能视为实际费用。

| 类别 | 题数 | 结果 |
| --- | ---: | --- |
| 单视频事实 | 3 | A 的全量重建、B 的增量索引、D 的浇水前土壤检查均命中预设关键点，引用相应真实片段。 |
| 跨视频综合 | 3 | A/B 差异、A/B/C 立场、索引主题与浇水主题均覆盖相关来源；最后一题引用 A/B/C/D 四个视频。 |
| 冲突 | 2 | A 的全量主张、B 的增量建议、C 的反对与样本不足并列呈现，没有按日期裁定。 |
| 证据不足 | 2 | 50% 降本及 B300 官方价格均明确回答无法确定，最终 `insufficient_evidence=true`、引用为空；没有编造价格或降幅。 |

首轮第 9 题正文已指出缺少成本数据，但结构化不足标记错误；收紧 query 指令后复测两题，均正确标记不足。再收紧自然语言指令并复测第 9 题，答案不再显示内部字段名，明确“缺少数据不等于证伪 50%”。一次较早的跨主题试跑因模型未提交结构化答案被拒绝；提高问答工具预算并明确必须调用提交工具后，完整 10 题运行无错误。迁移运行记录目录时，另一次真实试跑出现过 9 字占位式答案；增加最低内容长度并明确要求回答问题后，真实复跑输出 460 字、有原始片段引用的有效答案，显式保存与重复保存均通过。模型措辞仍可能随运行变化，故应用层坚持工具顺序、证据与提交校验。

首题审计记录实际 `skill_load → wiki_query_orientation → wiki_search → wiki_get_page → wiki_get_evidence → wiki_submit_answer`，包含规范/目录/日志哈希、模型、工具顺序、时长和估算费用。首题只读查询前后 Wiki 修订不变；显式保存增加一页，重复保存未增加修订。保存页搜索命中且证据按钮可解析到原视频时间。独立临时 profile 即使复制同一 run 文件，也因 wiki_id 不匹配而拒绝保存。

## 检查与限制

- `scripts/check.ps1`：Python VKC、Gateway、Feishu、安装器、Desktop 检查，以及 Ruff、格式、TypeScript、ESLint 和 Desktop 测试通过。
- `tests/video_knowledge/wiki/test_query.py`：只读、真实片段校验、伪造片段拒绝、显式保存与幂等、旧 query 页不得成为佐证、profile 隔离、技能不可用失败。
- `tests/video_knowledge/api/test_integration_controller.py` 与 Desktop `api.test.ts`：验证桌面控制器与客户端的 query/save 路由和权限分离。
- 真实模型验收使用合成视频和临时 Wiki；自然语言质量需持续复核。每次查询最多 40 次 Wiki 工具调用、42 次 Agent 迭代；大量页面或复杂问题可能达到预算并明确失败。私有 query run 记录目前保留在 profile 存储中，清理策略属于后续知识生命周期工作。已运行的 Hermes Desktop 后端需重启才会加载新代码。
