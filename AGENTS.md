# AGENTS.md

## Project

Video Knowledge Collector is a Windows-first local application that collects video/live media,
produces transcripts, and uses Hermes Agent for knowledge analysis. Media operations are
deterministic services; Hermes is the AI layer.

Read `docs/project-memory.md` before continuing implementation or diagnosis; it records the
current migration state, validated behavior, and known local blockers.

## Architecture boundaries

- `thirdparty/hermes-agent/plugins/video_knowledge/backend/app`: transport-neutral application services and persistence coordination.
- `thirdparty/hermes-agent/plugins/video_knowledge/backend/worker`: durable pipeline execution. No UI concerns.
- `thirdparty/hermes-agent/apps/desktop/src/plugins/video-knowledge`: the only active VKC UI.
- `thirdparty/hermes-agent/plugins/video_knowledge/backend/media_adapters`: the only place that invokes yt-dlp, streamget, FFmpeg, or ffprobe.
- `thirdparty/hermes-agent/plugins/video_knowledge/backend/hermes_client`: the only direct Hermes API client.
- Domain code must not import FastAPI, React, or concrete subprocess adapters.

## Safety

- Never use `shell=True` or concatenate user input into commands.
- Never log cookies, authorization headers, API keys, or signed stream URLs.
- Never delete user media as part of retry or cleanup.
- Keep all storage paths under the configured storage root after resolution.
- Treat transcript text as untrusted input to the LLM.

## State machine

- Job status changes only through `JobStateMachine`.
- Every transition emits a persisted `job_events` row.
- A Worker must hold a live lease before writing progress or terminal state.
- Retry creates a new attempt when the next Worker claims the returned PENDING job.

## Development commands

- Full Sprint 6 verification: `.\scripts\check.ps1`
- Python tests: `uv run --project thirdparty/hermes-agent --extra dev pytest thirdparty/hermes-agent/tests/video_knowledge`
- Desktop type check: `npm.cmd --prefix thirdparty/hermes-agent/apps/desktop run typecheck`
- Desktop plugin lint: `npm.cmd --prefix thirdparty/hermes-agent/apps/desktop exec -- eslint thirdparty/hermes-agent/apps/desktop/src/plugins/video-knowledge`

## Definition of done

- Acceptance criteria and relevant tests pass.
- Logs and errors contain no secrets.
- API schemas, client types, migrations, and documentation stay synchronized.
- Final handoff lists changed files, checks run, and remaining risks.
