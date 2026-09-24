# 视频知识 Wiki SCHEMA 示例（阶段 1 初始化模板）

`schema_version: 1`。本文件是设计样例，不会在阶段 0 创建实际 Wiki。

## 领域、页面和写入范围

领域为当前 Hermes profile 已收集的视频与直播中可追溯的知识。自动写入 `videos/`、`sessions/`、`concepts/`、`entities/`、`comparisons/`，用户明确保存的问答写入 `queries/`；`notes/` 仅用户维护。`raw/` 是不可变来源。生成页面路径采用稳定 ID，标题、别名可使用中文。允许的页面类型为 `video`、`session`、`concept`、`entity`、`comparison`、`query`。

标签先登记后使用。初始分类：`检索`、`模型`、`工程`、`评测`、`观点`、`争议`、`直播`、`生活`、`待复核`。标签仅帮助检索，不代表证据强度。新增标签需改 SCHEMA 版本并预览影响。

每个视频/直播分段可创建一个稳定页。同一主题或实体在两个独立来源实质讨论，或是单个来源的核心内容时，才建主题/实体页；过路提及不建页。同场直播切段不自动算两份独立佐证。对比页须至少有两个确实可比较的来源。模型的 confidence 不能代替证据核验。

## 证据、观点与更新

事实、作者观点、推断分别标识。结论级引用包含 `source_revision`、`media_id`、`transcript_id`、`segment_ids`、`start_ms`、`end_ms`；所有片段必须存在且时间落在 Transcript 内。没有可核验片段的摘要标为“来源概述”。不同作者相反观点并列显示、标 `contested`，不能按发表日期自动选胜者。降级分析只可形成带警示的视频页，不提升为确定的主题事实。

相同输入指纹重复运行不新增修订。新版分析产生新 source_revision 并保留旧历史。自动同步遇到正文外部修改，比较页面 hash 并标记冲突，禁止覆盖。`notes/` 保持独立。所有页面和 index/log 更新经应用提交，记录 commit_id。

## 页面示例

```markdown
---
page_id: video-media_fixture_a
type: video
title: 向量检索实战 A
aliases: []
tags: [检索, 观点]
created_at: 2026-09-24T00:00:00Z
updated_at: 2026-09-24T00:00:00Z
revision: 1
schema_version: 1
source_refs: [source_fixture_a_v1]
generation_metadata:
  mode: deterministic_video_export
  degraded: false
  compiler_version: 1
---

# 向量检索实战 A

作者主张每次新增资料都重建索引。 [证据](../raw/videos/media_fixture_a/source_fixture_a_v1/transcript.md#a2)
```

Markdown 证据链接只用于阅读；实际播放器跳转从结构化引用投影解析 `media_id` 和 `start_ms`，导航到 `/video-knowledge?media=<encoded-id>&t=<milliseconds>`。若原媒体已删除，页面及快照仍可阅读，播放器提示不可用。
