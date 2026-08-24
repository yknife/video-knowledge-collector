# Video Knowledge Collector 项目记忆

更新时间：2026-08-17（Asia/Shanghai）

## 项目位置

- 主工程：`D:\workspace\video-knowledge-collector`
- 当前桌面任务可能仍显示旧的 C 盘工作区；执行命令和修改文件时应明确使用上述 D 盘路径。
- 仓库当前尚未建立首个 Git 提交，文件在 `git status` 中可能全部显示为未跟踪；不要因此删除或覆盖现有内容。

## 已完成范围

- Sprint 1：FastAPI、React/Vite、SQLite/Alembic、配置、日志、健康检查及前后端联调。
- Sprint 2：持久化任务队列、严格状态机、Worker 租约与恢复、任务事件、WebSocket、任务中心。
- Sprint 3：普通视频采集、媒体校验与媒体库。
- Sprint 4：字幕下载、Transcript 规范化、全文搜索和播放器联动。
- Sprint 5：无字幕 faster-whisper ASR、分片检查点续跑、设备配置与资源提示，应用版本为 `0.5.0`。

## Sprint 3 关键实现

- `Source`、`MediaItem`、`MediaAsset` 数据模型。
- Alembic 迁移头：`20260816_0003`。
- URL 规范化、跟踪参数清理、私有/本机 IP 拒绝以及规范 URL 去重。
- yt-dlp 探测与下载；默认通过当前 Python 执行 `python -m yt_dlp`。
- ffprobe 音视频流和时长校验。
- 下载进度映射、取消时终止子进程、Cookies/代理配置、稳定错误码和错误脱敏。
- 校验成功后才登记媒体，文件存放在 `storage/media/{media_id}/source/`，并记录 SHA-256。
- API：`POST /api/v1/sources/probe`、`POST /api/v1/sources/ingest`、`GET /api/v1/sources`、`GET /api/v1/media`、`GET /api/v1/media/{id}`。
- 前端：`/add` 添加内容、`/media` 媒体库、`/jobs` 任务中心。

## Sprint 4 关键实现

- 优先人工字幕、后备自动字幕，并支持语言优先级配置。
- 解析 SRT、VTT、ASS/SSA 和 JSON3，清理标签、空白与相邻重复片段。
- `Transcript`、`TranscriptSegment` 与 FTS5 trigram 全文索引。
- `GET /api/v1/media/{id}/transcript`、`POST /api/v1/media/{id}/transcript`、`GET /api/v1/search`。
- 本地媒体 Range 播放、Transcript 搜索、当前片段高亮和点击时间戳跳转。

## Sprint 5 关键实现

- 无字幕时自动回退 ASR；FFmpeg 抽取并登记 `16 kHz / mono / pcm_s16le` WAV 音频资产。
- faster-whisper 模型按模型、设备和计算类型延迟加载及进程内复用；支持语言、VAD 与词时间戳配置。
- `auto` 设备检测：有可用 CUDA 时默认 `float16`，否则 CPU `int8`。
- 长音频按默认 120 秒、1.5 秒重叠分片；合并时修正全局时间戳并去除重叠边界重复。
- 每个 ASR 分片原子写入 JSON 检查点；任务取消/进程中断后，同一任务重试会跳过已完成分片。
- Transcript 继续复用 Sprint 4 的版本、片段与 FTS5 索引，并记录模型和实际运行配置。
- `GET /api/v1/system/asr`、添加内容页 ASR 参数，以及 `/settings/asr` 配置与资源建议页面。
- 默认配置在 `.env.example` 的 `VKC_ASR_*` 和 `VKC_FFMPEG_PATH` 中。

## 最近验证结果

- `scripts/check.ps1` 全部通过。
- Python：32 项 pytest 测试通过。
- Ruff、mypy、ESLint、Vitest、TypeScript 和 Vite production build 通过。
- yt-dlp 版本：`2026.07.04`。
- ffprobe 版本：`8.1.2`。
- API 健康检查目标版本为 `0.5.0`。
- Sprint 5 修复：自动重试会从已记录进度继续，Pipeline 重放时不再因进度倒退失败；ASR 错误会保留受限长度的底层异常信息。

## 常用命令

```powershell
Set-Location -LiteralPath 'D:\workspace\video-knowledge-collector'
.\scripts\dev.ps1
```

开发地址：

- Web：<http://127.0.0.1:5173/>
- API：<http://127.0.0.1:8000/>
- OpenAPI：<http://127.0.0.1:8000/docs>

完整检查：

```powershell
Set-Location -LiteralPath 'D:\workspace\video-knowledge-collector'
.\scripts\check.ps1
```

数据库升级：

```powershell
uv run alembic upgrade head
```

## 后续工作建议

- 下一阶段按详细设计文档继续 Sprint 6（Hermes AI 分析）。
- 开始新 Sprint 前先读取 `Video Knowledge Collector 详细设计文档.md` 对应章节。
- 若需要验证真实平台下载，使用用户明确提供的公开视频 URL；自动化测试目前通过假的命令运行器验证适配器和媒体登记，不会产生网络下载成本。
- 保持任务状态修改只通过 `JobStateMachine`，外部命令禁止使用 `shell=True`，媒体文件仅在 ffprobe 校验成功后入库。
