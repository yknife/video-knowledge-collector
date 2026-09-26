# Wiki 提问工作目录丢失修复（2026-09-26）

## 判断与证据

需要修复前端入口，不能取消后端工作目录校验。用户确认通过知识库的“向知识库提问”按钮进入；真实 `state.db` 中 `20260926_212046_17bbe2`、`20260926_214329_09887e` 两次 Desktop 会话的 `cwd` 都为空，问题文本也未注入首轮 `/llm-wiki` 上下文。之前成功进入研究的 `20260926_181529_b51fef` 则记录了 `D:\vkc\storage\wiki`。

按钮通过 `host.newChat` 请求带目录的新草稿，同时导航到 Chat。`ContribWiring` 先处理新草稿请求，再运行 `useRouteResume`。两者在同一次 React commit 中执行时，前者已写入 Wiki 目录，但后者仍读取本轮渲染中的旧 `freshDraftReady`/会话状态，于是再次执行不带目录的 `startFreshSessionDraft(true)`，清掉显式目录。随后首轮中间件因目录不匹配跳过技能上下文，后端创建普通 Desktop 会话并拒绝 Wiki 工具。

回归测试使用真实 `useSessionActions` 和 `useRouteResume`，按上述顺序执行 effect。修复前稳定失败：预期 `D:\vkc\storage\wiki`，实际 `$newChatWorkspaceTarget` 为 `undefined`；修复后目录保留，实际 `session.create` 请求带正确 `cwd` 和 `source: desktop`。

## 修改文件

- `thirdparty/hermes-agent/apps/desktop/src/app/session/hooks/use-route-resume.ts`：重置新草稿前读取即时 `$freshDraftReady` 和会话 refs；如果同一 commit 的前一个 effect 已准备好草稿，不再用旧渲染状态重复初始化。
- `thirdparty/hermes-agent/apps/desktop/src/app/session/hooks/use-session-actions.test.tsx`：增加上述前端跨 hook 时序回归测试。
- `thirdparty/hermes-agent/plugins/video_knowledge/wiki_chat_tools.py`：保持工作目录校验；拒绝时返回 `WIKI_WORKSPACE_REQUIRED`、中文操作说明及不可自动重试标识，要求模型停止操作，不自行检查/修改应用代码或会话记录绕过校验。
- `thirdparty/hermes-agent/tests/video_knowledge/tools/test_video_knowledge_tools.py`：使用真实 SessionDB 验证未绑定会话不能发起查询/保存、数据库连接正确释放，正确绑定的会话仍可调用服务。
- `scripts/check.ps1`：把会话操作、路由恢复和 Wiki 提问上下文测试纳入常规检查，避免只测试提问中间件却遗漏入口时序。

## 验证与生效

- 115 项 Desktop 测试通过，包含 75 项会话操作、路由恢复和 Wiki 提问上下文测试；相关前端 lint 通过。
- 完整检查通过：391 VKC、148 Gateway、78 Feishu、1 installer 测试及 Python lint/format、Desktop typecheck/plugin lint；新增聊天工具模块另按相同严格规则检查通过。扩展后的 7 个 Desktop 测试文件也已单独按检查脚本命令全部运行通过。
- 未更改用户 Wiki 或历史聊天目录，没有数据库迁移。旧的错误会话仍是普通聊天，应从知识库按钮进入新的 Chat。
- 前端修复需加载新代码；本机使用 Vite 开发服务，可热更新。后端错误提示需重启 Desktop 后端；完整退出并重新打开 Desktop 后再进入新 Wiki Chat，可同时加载两部分改动。单独重启 Gateway 不能修复旧会话的目录。
- 本次没有驱动用户正在运行的 Desktop 窗口重新发送问题；测试已覆盖导致丢目录的实际 hook 顺序和发往后端的创建参数。
