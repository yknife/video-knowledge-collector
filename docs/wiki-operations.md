# 视频知识库使用与运维

## 自动入库与历史补录

在 Hermes Desktop 的 VKC「知识库」中初始化 Wiki，按需开启「分析完成后自动入库」。开关只影响以后完成的分析；已有分析可在媒体详情选择「手动入库」，或在知识库补录界面先预览再提交。入库只读取已有 Transcript 和四份分析文档，不下载媒体、不重新转写、不重新分析。视频来源页提交后，跨视频融合由独立的 `WIKI_FUSE` 任务执行；融合失败不会撤销已提交的视频页。

批量运维可用 `thirdparty/hermes-agent/scripts/wiki_stage8.py`。先运行 `backfill` dry-run，核对 `NEW`、`VERSION_UPDATE`、`REVIEW` 和跳过数；确认范围后增加 `--apply`。`--media-id` 可重复传入以限定范围，`--limit` 默认 10，`--interval-seconds` 默认 1 秒，逐项结果包含任务 ID 或错误类型。`--report` 可将结果保存到受控私有目录；完成后用返回的 batch ID 执行 `backfill-status`，取得每项基础入库、融合任务与提交状态。重复补录同一分析版本不会生成重复任务或页面。

```powershell
$dbUrl = 'sqlite+aiosqlite:///' + ($env:LOCALAPPDATA + '/hermes/video-knowledge/data/app.db').Replace('\\', '/')
$wikiRoot = 'D:\vkc\storage'
uv run --project thirdparty/hermes-agent python thirdparty/hermes-agent/scripts/wiki_stage8.py backfill --database-url $dbUrl --storage-root $wikiRoot --limit 10
uv run --project thirdparty/hermes-agent python thirdparty/hermes-agent/scripts/wiki_stage8.py backfill --database-url $dbUrl --storage-root $wikiRoot --limit 10 --interval-seconds 2 --apply
$batchId = 'wiki_batch_...' # 替换为上一步返回的 batch_id
uv run --project thirdparty/hermes-agent python thirdparty/hermes-agent/scripts/wiki_stage8.py backfill-status --database-url $dbUrl --batch-id $batchId --report D:\vkc-reports\batch-status.json
```

## 阅读、失败与人工维护

知识库目录和搜索只显示已确认的页面修订。打开页面的时间引用可跳转到媒体播放器；若原媒体不在本机，来源快照仍可阅读，但回看会提示媒体缺失。知识库问答会读取已提交页面与原始片段，答案需要有效引用；只有显式「保存到知识库」才会产生页面提交。结构巡检检查索引、断链、来源与外部编辑；语义巡检调用 Hermes 模型给出待人工复核的建议。

同步失败时查看任务中心的错误码与最后的校验原因。`WIKI_INGEST` 与 `WIKI_FUSE` 独立重试；已提交视频页不会因融合失败消失。遇到 `WIKI_CONFLICT`，先查看页面差异和外部编辑，再选择人工协调或重试。争议主张应保留不同来源与证据，人工判断后再修改。生成页的人工修改应走桌面端复核提交，避免外部直接改写导致冲突。撤回来源会让当前页不再把该来源视为有效支撑，历史快照仍保留；删除原媒体不等于撤回知识。

## 备份与恢复

可靠备份必须同时包含业务 SQLite 数据库和完整 `wiki/` 目录。`backup` 命令取得 Wiki fencing 租约、恢复未完成的 PREPARED 提交、用 SQLite backup API 取得一致数据库快照，并在租约内复制 Wiki，写 SHA-256 清单后才发布目标目录；数据库副本会清除只属于原环境的临时 Wiki 租约。若有正在持有 Wiki 租约的 Worker，命令会拒绝；稍后重试。不要直接复制正在更新的 Wiki 目录。备份目录含私人分析与来源内容，应按私人资料保护。当前工具不复制原始媒体文件；备份中的业务数据库仍保留原媒体定位信息。

```powershell
uv run --project thirdparty/hermes-agent python thirdparty/hermes-agent/scripts/wiki_stage8.py backup --database-url $dbUrl --storage-root $wikiRoot --destination D:\vkc-backups\wiki-20260925
uv run --project thirdparty/hermes-agent python thirdparty/hermes-agent/scripts/wiki_stage8.py restore --backup D:\vkc-backups\wiki-20260925 --destination D:\vkc-restore-test
```

`restore` 只接受不存在的新目录，先校验清单与文件哈希，再写入 `app.db` 和 `storage/wiki/`。用恢复目录的数据库 URL 与 storage root 启动隔离测试实例，重建搜索索引，核对页面、来源和时间引用。若没有一并迁移原媒体，播放器回看会报告媒体缺失；不要把测试实例直接指向原环境的媒体路径。备份中留下的 `.partial-*` 目录代表未完成备份，不能用于恢复。

## 模型与费用

融合、知识库问答和语义巡检会调用当前 Hermes 配置的模型以及固定版本的 `llm-wiki` Skill；视频来源快照、搜索和结构巡检不需要模型。批量补录可能为每个来源排入融合任务，具体费用取决于 Hermes 提供方的计费与实际 token 使用量；自定义 provider 的内部估算值为 0 不代表免费。大量补录应先选少量样本并观察任务、费用和 Wiki 内容，再扩大范围。

升级 `llm-wiki` 时，先在隔离环境固定新 Skill 内容和 SHA-256，更新适配器固定哈希及版本并运行 ingest/query/lint 三条真实链路和完整回归；核对审计里的 Skill 哈希、方向文件哈希、工具顺序和提交/答案/报告 ID。通过后再部署并显式预览规范影响，按用户选择重编译受影响主题页。Skill 缺失、禁用或哈希不符会直接报错，不会退回到普通提示词；旧审计和页面修订保留，便于比较升级前后结果。
