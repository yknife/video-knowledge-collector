# Wiki 阶段 4 验收报告

- 状态：已通过（合成 Wiki 与 Desktop 组件测试）
- 日期：2026-09-24
- 前置：阶段 0—3 已通过；阶段 2/3 的未提交工作树改动已保留。
- 迁移：`20260924_0013` 新增 `wiki_search_state` 与可重建的 `wiki_page_fts`；不修改页面正文、媒体或分析文档。

## 实现

现有 Hermes Desktop 视频知识插件新增“知识库”页，沿用同一 FastAPI 后端、数据库和 Worker，无额外服务。后端从已确认的 Wiki 页面快照读取目录、页面、类型与标签、来源修订、页间链接和反向链接；引用 API 再验证不可变来源片段，返回媒体 ID 与毫秒时间，并告知媒体是否已移除。来源快照 API 可在媒体文件失效时继续显示 Transcript。

中文搜索将中文单字和相邻双字、英文词写入 FTS5 投影，再对候选页面做正文校验。Wiki 修订变化时自动重建；也提供手动重建 API。投影被清空或整个 FTS 表被移除后均可重建，页面正文哈希保持不变。

Desktop 页提供目录、关键词搜索、类型/标签筛选、Markdown 阅读、来源与引用列表、反向链接、自动入库开关、手动同步/重试、历史补录预览/确认/取消。媒体详情显示 Wiki 状态及页面入口。Wiki Markdown 用 React 文本节点渲染；仅已收录的 Wiki 页面链接和结构化引用按钮可点击。原始 HTML、图片、本地文件和危险 URL 不会作为可执行 DOM 或外部资源加载。

## API

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| GET | `/api/v1/wiki/pages` | 页面目录、类型与标签筛选；未初始化时返回明确状态。 |
| GET | `/api/v1/wiki/pages/{page_id}` | 已提交页面正文、来源、出站与反向链接。 |
| GET | `/api/v1/wiki/pages/{page_id}/citations/{item_key}` | 复核时间引用，返回播放器路由与媒体可用性。 |
| GET | `/api/v1/wiki/sources/{media_id}/{source_revision}` | 经哈希校验的不可变来源快照。 |
| GET | `/api/v1/wiki/search` | 中文/英文标题与正文检索，可按类型、标签过滤。 |
| POST | `/api/v1/wiki/search/rebuild` | 从已提交快照重建 FTS。 |

阶段 3 的设置、入库、补录和任务接口继续供该页面使用。

## 验收证据

| 要求 | 证据 |
| --- | --- |
| 单一入口 | `VideoKnowledgePage` 的现有插件路由新增“知识库”标签，复用 `bindApi` 的后端连接和运行时握手。 |
| A/D 中文搜索 | `test_chinese_search_rebuild_and_verified_citation` 在真实 SQLite/FTS5 与临时 Wiki 上验证“重建索引”只命中 A，“浇水”只命中 D；无结果为空列表。 |
| 引用时间 | 同一测试验证 A 的“章节-1”返回 `media_fixture_a`、`start_ms=10000` 和 `t=10000`；Desktop 点击测试验证按钮路由，媒体库在播放器元数据加载后设 `currentTime=start_ms/1000`。实际播放器误差仍受媒体可寻址性限制。 |
| 空状态与错误 | 单一 FastAPI 应用的 API 烟测验证未初始化、空搜索及缺页响应；删除媒体后引用仍指向来源快照并返回 `media_missing=true`，无效引用被拒绝。Desktop 分别显示无结果、目录/搜索/页面/来源错误与 Wiki 任务错误；长正文渲染测试保留第 1000 行。 |
| 索引重建 | 测试分别删除 FTS 行与整个虚拟表，手动重建后页面数量与关键词结果恢复，已提交页面 SHA-256 不变；迁移烟测确认 FTS 与状态表。 |
| 链接边界 | `wiki-markdown.test.tsx` 验证 `<script>` 只作文本、`javascript:` 与 `file:`/图片链接不可导航，已知页间链接与引用走受控回调。直播场次目录及反向链接由 `test_session_directory_links_and_backlinks` 验证。 |

验证：Wiki 定向测试 22 passed；Desktop Wiki Markdown 5 passed；完整 `scripts/check.ps1` 通过：349 VKC、148 Gateway、78 Feishu、1 installer、35 Desktop 测试，以及 Python lint/format、Desktop typecheck/lint。本阶段未向用户现有媒体库写入 Wiki 内容、启用自动入库或重启生产进程；未进行真实桌面播放器人工测时，引用跳转契约和播放器寻址路径已由代码与组件测试验证。
