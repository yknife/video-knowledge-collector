# Changelog

## 0.10.0-rc.1 - Sprint 10

- Added reproducible Windows NSIS/MSI packaging with fork-aware immutable install stamps.
- Added verified release manifests and SHA-256 checksums for every installer artifact.
- Added runtime version readiness for yt-dlp, streamget, faster-whisper, FFmpeg, and ffprobe.
- Reused Hermes Desktop supervision, model-download UI, update and data-preserving uninstall flows.
- Added Windows RC CI, user documentation, troubleshooting guidance, and release acceptance matrix.

## 0.6.0 - Sprint 6

- Restored Sprint 1-5 sidebar parity: source preview and collection options, job actions/events,
  faster-whisper model selection, media assets, local video playback, transcript search/seek,
  and ASR runtime guidance.
- Added Hermes controller contracts for source probing, ASR status, persisted job events, and
  validated local playback paths.
- Relocated the complete VKC Python backend, Worker, adapters, clients, tests, and migrations into the bundled `plugins.video_knowledge` Hermes package; Hermes no longer imports runtime code from the outer repository.
- Archived the retired standalone React application under the Hermes plugin while keeping the native Desktop plugin as the only active UI.
- Added a default-enabled Hermes Desktop Video Knowledge sidebar and workspace using the Hermes Plugin SDK and design tokens.
- Mounted the transport-neutral collector API at `/api/video-knowledge/v1/*` in Hermes `api_server.py`, with the Desktop plugin alias sharing Hermes profile and authentication.
- Added profile-scoped migration, database backup, supervised Worker startup/shutdown, parent-liveness cleanup, degraded health, and exponential restart backoff.
- Added an OpenAI-compatible Hermes client with Chat Completions/Responses modes, retries, structured JSON output, and untrusted-transcript prompting.
- Added automatic analysis jobs, map-reduce chunking, schema/citation validation, prompt fingerprints, and versioned summary, chapter, knowledge-point, and suggested-QA documents.
- Replaced the default three-process VKC launcher with a single Hermes Desktop launcher.

## 0.5.0 - Sprint 5

- Added FFmpeg 16 kHz mono PCM extraction and a lazy faster-whisper model adapter.
- Added automatic CPU/NVIDIA device resolution, VAD, word timestamp, language, model, and compute configuration.
- Added overlapping audio chunks, boundary de-duplication, durable chunk checkpoints, progress, and cancellation safe points.
- Added automatic ASR fallback for media without subtitles and persisted model/runtime metadata on Transcript versions.
- Added ingestion ASR controls, an ASR runtime/settings page, and CPU/GPU configuration-path tests.
- Fixed automatic retries replaying lower progress values and hiding the original ASR failure.
- ASR model loading and inference errors now preserve a bounded root-cause message for diagnosis.
- Manual retry now grants a fresh attempt budget while keeping append-only attempt history.
- Windows CUDA detection now verifies cuBLAS and cuDNN DLLs and falls back to CPU int8 when the runtime is incomplete.
- ASR retries with registered local audio now bypass remote platform probing, so rate limits cannot block checkpoint recovery.

## 0.4.0 - Sprint 4

- Added subtitle discovery, language preference, manual/automatic subtitle download, and stable subtitle errors.
- Added SRT, VTT, ASS/SSA, and JSON3 parsing with cleanup, duplicate merging, coverage checks, and versioned Transcript storage.
- Added SQLite FTS5 transcript search, Range media streaming, and media detail player with timestamp seeking.

## 0.3.0 - Sprint 3

- Added canonical video sources, media items, verified media assets, and database migration.
- Added yt-dlp probing/downloading, ffprobe validation, progress reporting, cancellation, and stable error mapping.
- Added duplicate-ingest protection, Add Content workflow, and the local media library.

## 0.2.0 - 2026-08-16

- 新增持久化 jobs、job_attempts、job_events 和严格任务状态机。
- 新增原子任务领取、Worker 租约续期、超时恢复及协作式取消。
- 新增 Jobs REST API、跨进程 SQLite WebSocket 事件流与前端任务中心。
- 新增 10 任务并发领取、崩溃恢复、终态保护和实时 UI 测试。

## 0.1.0 - 2026-08-16

- 完成 Sprint 1 单仓库工程骨架。
- 建立 API、Worker、Web、共享包、数据库迁移和质量检查链路。
- 实现前端到后端及 SQLite 的健康检查联调。
