# Wiki Chat 提问预算耗尽修复（2026-09-26）

## 原因

截图中的三次提问均加载了固定版本的 `llm-wiki`，使用 `deepseek-flash / custom:deepseek`。查询审计分别耗时约 145、119、95 秒；第二、三次均进行了 32 次搜索、7 次页面读取和 1 次方向读取，刚好耗尽 40 次额度。日志中随后读取原始证据、提交答案全部返回 `Wiki query tool budget exceeded`。

问题在于搜索、证据读取和答案提交共用一个硬上限；用完额度后，即使模型尝试提交“证据不足”，也无法结束研究。聊天桥接又把原因缩成 `WikiAgentError`，外层模型于是重新表述问题、重复启动研究。

## 改动

- `thirdparty/hermes-agent/plugins/video_knowledge/backend/hermes_client/wiki_query.py`：保留 40 次读取上限，搜索单独限制为 8 次；提交答案不消耗读取额度。工具返回剩余额度和后续动作提示。答案引用 schema 补齐字段，仍严格校验已读页面、版本、原始片段及时间范围。失败审计保留静态校验原因。
- `thirdparty/hermes-agent/plugins/video_knowledge/backend/hermes_client/wiki_agent.py`：说明搜索为字面关键词匹配、多词必须同时命中；要求少量聚焦搜索后转向原始证据并及时提交。
- `thirdparty/hermes-agent/plugins/video_knowledge/wiki_chat_tools.py`：未提交有效答案时返回安全的原因、错误码、run ID 和禁止自动重复研究的提示。模型仍通过原有 `wiki_save` 决定是否保存通过校验的答案。
- `thirdparty/hermes-agent/tests/video_knowledge/wiki/test_query.py`、`tests/video_knowledge/tools/test_video_knowledge_tools.py`：覆盖搜索耗尽后仍可读证据、读取耗尽后仍可修正并提交答案、证据不足不允许保存，以及失败审计和聊天错误转译。

## 验证与生效

- 完整 `scripts/check.ps1` 通过：389 VKC、148 Gateway、78 Feishu、1 installer、40 Desktop 测试，以及 Python 格式/lint、Desktop typecheck/lint。
- 最后补充审计原因后，16 项提问和插件工具定向测试再次通过；聊天工具模块单独按根脚本同等严格规则检查。
- 对真实 Wiki 修订 199 做只读数据库快照和文件副本，以实际 `deepseek-flash / custom:deepseek` 重问截图原问题：成功 run `wq_b0ef9b96daba414aa0bebbb8cf516453`，耗时约 134 秒；8 次搜索、6 次页面读取、10 次证据读取，最后提交 10 条校验通过的引用。模型两次提交失败后在同一研究回合内修正成功，期间出现输出长度截断提示，因此本修复不承诺提问耗时降低。提问前后副本 Wiki 文件哈希一致。
- 随后仅在隔离副本执行受控保存，Wiki 修订从 199 到 200；重复保存幂等，不新增修订。真实 Wiki 没有试写。真实模型隔离验证证据保存在本机忽略目录 `artifacts/wiki-query-fix/`，不纳入版本库。
- 本次为 Python 后端改动，没有数据库迁移。运行中的 Desktop 后端需要重新加载代码；完整退出 Hermes Desktop 并重新打开、从知识库进入新 Chat 是明确的生效方式。不能把刷新网页视为后端重启。
- 未重启当前 Desktop，也未验证真实聊天界面中外层模型自主保存/不保存的选择；已验证同一底层查询及保存服务、桥接错误回传和会话约束。
