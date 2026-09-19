# Video Knowledge Collector 项目记忆

## 2026-09-20 Task cards contain long URLs

- Task-center columns and Radix ScrollArea content can now shrink to the available width instead
  of inheriting a long URL's intrinsic width. Source labels and error details wrap at arbitrary
  URL boundaries, while progress remains visible at the card's right edge.
- The task header and event column use flex sizing rather than fixed height subtraction, so wrapped
  source labels do not create a horizontal page overflow or clip the scrollable task list.
- Desktop TypeScript checks, plugin lint and the 28 focused Video Knowledge tests pass. The running
  development desktop picked up the change through Vite HMR and was inspected at its normal size.

## 2026-09-19 Feishu Bilibili live short-link routing

- Collection admission resolved only Xiaohongshu, Douyin and Weibo short links before
  classifying the job. A `b23.tv` live share therefore became INGEST_VIDEO and failed
  when probing discovered a live stream. Admission now resolves every supported short
  link through MessagingUrlGuard before selecting RECORD_LIVE or INGEST_VIDEO.
- Existing message replay still bypasses network resolution. Regression tests cover
  Bilibili live/video redirects and replay; unrelated notification tests use direct
  video fixtures to avoid external network dependencies.
- The reported short link was verified to resolve to `live.bilibili.com/544843`.
  Failed job `job_01789824587550269500_b813b3d51c` is retained for audit. Replacement
  workflow `workflow_01789824909047230600_56b4060b8c` uses the original trusted Feishu
  origin and a separate deterministic repair receipt key. Its RECORD_LIVE job reached
  RECORDING with increasing progress; hourly segmentation and analysis remain enabled.
- Gateway was restarted using the repository .venv Python; health is OK and the Feishu
  WebSocket reconnected. When restarting on Windows, use `.venv/Scripts/python.exe`,
  not the underlying interpreter path reported by a child process (which loses venv
  dependencies). Full-hour completion and final result delivery remain pending.
- Validation: `scripts/check.ps1` passed (323 VKC, 148 gateway, 78 Feishu,
  1 installer and 30 desktop tests, plus lint, formatting and desktop type checks).
  The replacement recording had written a 24 MB segment at the final runtime check.

## 2026-09-19 Weibo thumbnail localization

- Weibo probe metadata supplied a valid `sinaimg.cn` thumbnail URL, but that host returned HTTP 403
  unless the request included `Referer: https://weibo.com/`. Electron image elements cannot safely
  attach this platform-specific header, so the library displayed a broken image.
- New on-demand ingests now extract a JPEG thumbnail from the already downloaded, validated video
  for every platform and persist it as a local THUMBNAIL asset. Desktop uses the existing
  `hermes-media://` protocol for these files and no longer depends on expiring or hotlink-protected
  image URLs.
- Worker startup backfill also replaces legacy remote Weibo thumbnail URLs with locally extracted
  files. Plugin version `0.21.2`; the ingest regression test asserts the saved local thumbnail.

## 2026-09-19 analysis retry progress and one-slot compaction fix

- Job `job_01789798780977734200_4bf049ba65` first failed at 81.9% with `division by zero` while
  compacting 11 mapped bundles. The deterministic `evenly()` selector divided by `limit - 1`
  when an anchored collection had exactly one remaining output slot.
- Automatic retries retain total job progress. The analysis callback restarted its per-attempt
  counter at 1/13 and requested 16.5%, so the state machine correctly rejected the decrease and
  replaced the useful failure with `JOB_PROGRESS_INVALID` on attempts two and three.
- One-slot selection now deterministically takes the first candidate; non-positive limits return
  no items. Analysis progress is clamped to the attempt's starting total until new work catches up.
  The state machine's global monotonic-progress invariant remains unchanged.
- Plugin version `0.21.1`. Regression tests reproduce both the 11-bundle/one-slot compaction and
  an analysis retry starting from 82%. Full checks pass with 321 VKC tests.

## 2026-09-19 Feishu Weibo video and live collection

- Desktop and Feishu now recognize Weibo on-demand posts, mobile status/detail pages, Weibo TV
  video pages, `t.cn` official shares, `/l/wblive/.../show/{id}` live rooms and numeric `/u/{id}`
  live profiles. Short links resolve before admission and must remain on an approved Weibo shape.
- Weibo on-demand collection uses yt-dlp. Live collection uses StreamGet's `WeiboLiveStream` and
  reuses hourly splitting, unlimited total recording, per-part transcription, Hermes analysis and
  Feishu outbox delivery. Platform labels and retry messages identify Weibo correctly.
- System settings expose a Weibo Netscape Cookies file. The same selected file is passed privately
  to on-demand and live adapters and refreshed on retry. No database migration is required.
- Plugin version `0.21.0`. Automated coverage includes URL admission/rejection, redirect platform
  binding, Cookie selection, real StreamGet parser behavior, offline/online status and hourly live
  workflow behavior. A user-supplied active Weibo live link has not yet been recorded end to end.

## 2026-09-19 Feishu runtime dependency preservation

- Gateway was running but skipped Feishu on 2026-09-18 restart because `lark-oapi` and `qrcode`
  were absent and automatic installation failed. `scripts/dev.ps1` previously used exact
  `uv sync --extra dev`, which can remove separately installed Feishu dependencies.
- The development launcher now explicitly selects `--extra feishu` and uses `--inexact` to retain
  other installed optional integrations. Existing `uv run` verification commands are inexact by default.
- Restored lark-oapi 1.6.8 and qrcode 7.4.2 with their dependencies; imports passed. Repeating the
  launcher sync with `--dry-run` reports no changes. PowerShell parsing and diff checks passed.
- Restarted only the messaging Gateway; on 2026-09-19 at 14:00:22 it reported `feishu connected`
  and two active platforms. Desktop and VKC Worker remained running. No test message was sent.

## 2026-09-17 Douyin mobile live cookie compatibility fix

- Failed live job `job_01789658238867563900_eb90aad8e6` reproduced with configured Douyin cookies:
  the mobile reflow API returned no usable room, while the identical URL worked anonymously.
  The original live smoke test had not exercised this user's cookie configuration.
- Reflow parsing now retries once without cookies for malformed/empty room responses; valid offline
  responses do not trigger fallback. Saved cookies are unchanged. A failed fallback retains a specific
  sanitized error instead of the generic parser failure. No response bodies or credentials are logged.
- The failed task URL with the configured cookie file now produced a real 5.294-second recording.
  Adapter and live pipeline regression tests: 66 passed; targeted lint/format passed.

## 2026-09-17 Feishu Douyin live collection

- Feishu accepts `live.douyin.com/{room}` and official `v.douyin.com` shares. Short links are
  resolved before admission and classified as live or on-demand; replay does not resolve again.
  Mobile `webcast.amemv.com/douyin/webcast/reflow/{id}` links retain `sec_user_id` and use the
  fixed reflow API through StreamGet signing/transport, without following another share redirect.
- Both web and mobile parsing use the configured Douyin cookies. Mobile parsing selects cookies
  against the Douyin domain before supplying them to the official mobile API. Room and stream URL
  validation remain active. Hourly splitting, unlimited total duration and per-part analysis/delivery
  reuse the existing live workflow. Platform labels now identify Douyin. Plugin version `0.20.0`.
- The user's basketball share `https://v.douyin.com/uu8xY3bhoD4/` resolved successfully; anonymous
  probing and a real FFmpeg sample succeeded (5.014 seconds, 3,875,817 bytes). Full-hour recording
  and actual Feishu delivery have not been exercised for this platform.
- Full `scripts/check.ps1` passed: 289 VKC, 148 Gateway, 78 Feishu, 1 installer and 30 desktop
  tests, plus lint/format and desktop type checks. Douyin parser tests cover web/mobile, cookies,
  offline rooms, short-link classification/replay and hourly continuation.

## 2026-09-16 Feishu Xiaohongshu live collection

- Messaging accepts numeric Xiaohongshu `/livestream/{id}`, `/hina/livestream/{id}`, and
  `/livestream/{route}/{id}` room URLs. Official xhslink short links are resolved by MessagingUrlGuard before the
  admission transaction to distinguish live rooms from on-demand notes; replayed messages reuse existing receipts
  without resolving expired links. Cross-platform redirects and non-global DNS remain rejected.
- Xiaohongshu uses StreamGet's `RedNoteLiveStream.fetch_app_stream_data` rather than the generic web method.
  Configured platform cookies are attached to its mobile request headers; Netscape expiry zero is treated as a
  session cookie without accepting actually expired cookies. Live retries also refresh platform cookies.
- Hourly splitting, unlimited total capture, cancellation, per-part analysis and Feishu outbox delivery reuse the
  Bilibili pipeline with platform-correct labels. Version `0.19.0`; no database migration.
- User-provided `https://xhslink.cn/o/5iyv4JKpyTf` was resolved over the real network to a Xiaohongshu note, not a
  live room. The subsequently supplied `https://xhslink.com/o/7rVauHiUZnT` resolved to a live room;
  real StreamGet probing and FFmpeg recording succeeded (5.454 seconds, 1,602,977 bytes), without configured
  Xiaohongshu cookies. Signed URLs and tokens were not logged. Full checks passed (275 VKC, 148 Gateway,
  78 Feishu, 1 install-source, 30 desktop tests). A full hourly recording and Feishu delivery were not exercised.

## 2026-09-13 Feishu new-user pairing with an owner allowlist

- A nonempty `FEISHU_ALLOWED_USERS` caused the Feishu adapter to drop unknown private senders before Gateway could
  offer pairing. Drops were DEBUG-only, so the normal log contained no inbound entry for these users.
- The adapter now honors explicit `platforms.feishu.extra.unauthorized_dm_behavior: pair` and forwards private
  messages to Gateway authorization even with an existing owner allowlist. Unapproved users cannot run the Agent;
  pairing approval remains required. Group and bot admission retain their existing checks. Rejection reasons are
  logged at INFO without message contents. Local profile config now explicitly enables pairing and has a backup.
- Feishu admission, authorization, and adapter regression tests: 95 passed. No unsolicited pairing message is sent;
  a new inbound private message triggers the normal pairing handshake.

## 2026-09-13 unlimited messaging duration

- `VKC_MESSAGING_MAX_VIDEO_DURATION_SECONDS=0` is now the default and disables the on-demand duration check,
  including for unknown-duration videos. URL, storage, and admission quota checks remain independent.
- Live recording uses `recording_remaining_seconds=0` for unlimited hourly continuation. Every part remains capped
  at one hour; recording stops on stream end or cancellation. Regression tests exercise continuation beyond three
  hours and cancellation of the fifth part. Plugin version is `0.18.1`.

## 2026-09-13 Feishu Bilibili hourly live recording

- Feishu accepts numeric `https://live.bilibili.com/{room_id}` room URLs through the existing trusted collection
  tools and Gateway fast admission, including bare room links. Other live platforms and live short-link redirects
  are not part of this release. Existing video-link behavior remains available.
- Each live submission creates an isolated recording chain. The recording unit is 3,600 seconds; a full part queues
  the next recording with higher priority than transcription. Each part has its own ingest/analysis workflow and
  trusted Feishu subscription. Automatic parts do not consume additional daily submission quota.
- Total recording retains the configured three-hour limit. Stream end saves and analyzes a short final part; an
  offline room returns a bounded unavailable result rather than entering permanent monitoring. Cancelling the latest
  recording prevents its continuation. Bilibili system cookies are passed privately to StreamGet when configured.
- Room and stream DNS are checked before recording. Notifications use the existing persisted outbox. No DB migration
  is required. Plugin version is `0.18.0`. Validation uses deterministic recording fixtures; real one-hour live
  capture and Feishu result delivery still require a user-submitted active room.

## 2026-09-13 three-hour Feishu video duration limit

- The default Feishu on-demand video collection limit is now 10,800 seconds (three hours), replacing the original
  1,800-second limit. The configured safety range remains 1–86,400 seconds.
- Retrying a failed messaging ingest refreshes the job's duration limit from current runtime settings together with
  its platform cookie configuration. Jobs rejected under the old 30-minute limit can therefore be retried after the
  restart without resubmitting the URL. Plugin version is `0.17.2`.

## 2026-09-13 Feishu collection priority and desktop browser isolation

- A Feishu direct-message session could remain blocked on an older Agent `clarify` call. A new explicit VKC video
  request was then interpreted as conversational input, allowing the Agent to invoke browser tools before collection
  admission. Explicit supported video requests now enter the durable VKC admission path before busy-session,
  steer/queue, pending-update, or clarify routing.
- The source development launcher previously left Electron's renderer DevTools port enabled. Agent browser tooling
  could attach to that port and navigate the Hermes desktop renderer to a media website. `scripts/dev.ps1` now starts
  the VKC desktop with `HERMES_DESKTOP_CDP_PORT=off`, isolating the application window from browser automation.
- A quota rejection remains an admission result and is returned immediately; it no longer falls through to Agent
  browsing. Plugin version is `0.17.1`.

## 2026-09-13 configurable Feishu collection quotas

- VKC System Settings now exposes a persisted Feishu collection quota switch and four bounded limits: active workflows
  per user/chat and daily submissions per user/chat. Defaults continue to come from the existing `VKC_MESSAGING_*`
  environment settings until an operator saves UI values.
- Messaging admission reads `messaging.quotas` from `app_settings` in the same transaction as quota enforcement, so UI
  changes take effect on the next Feishu submission without restarting Gateway or the Worker. Disabling the switch
  bypasses quota counting while leaving the trusted-user gate, URL policy, storage reserve, and media limits intact.
- Rejections now identify the exact exceeded dimension and current/limit values instead of returning only the generic
  `Messaging collection quota exceeded` message. Plugin version is `0.17.0`.

## 2026-09-13 Xiaohongshu CN short-link correction

- Feishu share text uses the official `xhslink.cn/o/...` domain, while the initial Xiaohongshu messaging allowlist only
  included `xhslink.com`. The rejected tool input caused Hermes to fall back to generic terminal and browser tools,
  which produced unnecessary visible steps and loaded Xiaohongshu into the desktop browser view.
- `xhslink.cn` is now classified as Xiaohongshu throughout messaging admission and source normalization. Its official
  short-link endpoint may return 404 to HEAD while GET still redirects, so the guarded resolver uses a streaming GET
  fallback for Xiaohongshu HEAD 404/410 responses. Every redirect target still passes platform, URL-shape, hop-count,
  and global-DNS checks before yt-dlp runs. Plugin version is `0.16.1`.

## 2026-09-13 Feishu Xiaohongshu collection

- Trusted Feishu collection now accepts yt-dlp-compatible Xiaohongshu note URLs at
  `www.xiaohongshu.com/explore/{id}` and `www.xiaohongshu.com/discovery/item/{id}`, plus official
  `xhslink.com` share links.
- Official share links are resolved with the existing redirect limit, per-hop allowlist and global-DNS checks. A safe
  streaming GET fallback handles share hosts that reject or render HEAD requests, and redirects may not cross to
  Bilibili or Douyin. Required note query values such as `xsec_token` remain intact.
- The Worker verifies yt-dlp's final extractor and webpage URL are still Xiaohongshu before download. New and retried
  Feishu jobs resolve the Xiaohongshu Netscape cookie file from VKC System Settings, and retry guidance uses the
  authoritative Xiaohongshu label. Plugin version is `0.16.0`.

## 2026-09-13 messaging retry cookie refresh

- Workflow `workflow_01789267866259066201_9776a91124` was correctly classified as Douyin, but its first job was created
  before the Douyin cookie file was configured. Manual retry reused the original immutable input and therefore repeated
  the anonymous probe, producing a second `AUTH_REQUIRED` failure.
- Messaging retry now atomically refreshes the current platform cookie path in the failed ingest job before returning it
  to PENDING. Retry/status results include the authoritative source platform, and retry responses include the previous
  error code plus a deterministic cookie-refresh message so the model does not mislabel a Douyin failure as Bilibili.
- The configured Douyin Netscape file contains valid current Douyin-domain rows. A redacted live probe of the reported
  short URL succeeds as platform `douyin` with a 1,466-second duration, and the messaging URL guard resolves it to an
  approved `iesdouyin.com/share/video/...` URL. Plugin version is `0.15.1`.

## 2026-09-12 Feishu Douyin collection

- Trusted Feishu collection now accepts exact Douyin on-demand URLs, official `v.douyin.com` short links, official
  `iesdouyin.com/share/video/...` links, and numeric discovery/featured `modal_id` links in addition to Bilibili.
- Numeric Douyin modal links are canonicalized to `/video/{id}` before network access. Short-link redirects retain the
  existing five-hop cap and global-DNS checks, and may not cross from Douyin to Bilibili or vice versa. The Worker also
  verifies that yt-dlp reports the same expected platform before download.
- Feishu jobs automatically use the per-platform Douyin cookie file configured in VKC System Settings. Anonymous live
  probing of the reported Douyin fixture reaches the extractor and returns the expected bounded `AUTH_REQUIRED` result;
  a current cookie export is still required when Douyin enforces login or IP risk controls. Plugin version is `0.15.0`.

## 2026-09-12 per-platform cookie settings

- VKC System Settings now manages validated Netscape cookie files independently for Bilibili, Douyin, Xiaohongshu,
  YouTube, Vimeo, and Twitch through the native desktop file picker. Only the local path is persisted; cookie contents
  remain outside API job responses, logs, notifications, and model context.
- Desktop probes, REST/controller ingestion, and trusted messaging collection resolve the cookie file from the URL
  platform. A file selected for one Add Content request still overrides the system default, and each queued job keeps
  the resolved path it was created with.
- Platform cookie settings use the existing `app_settings` table, so no schema migration is required. Plugin version is
  `0.14.0`.

## 2026-09-09 Douyin featured-link probing

- Desktop probing now canonicalizes numeric Douyin discovery/featured overlay URLs such as
  `douyin.com/jingxuan?modal_id=...` to the stable `/video/{id}` work URL before invoking yt-dlp. This prevents a
  supported Douyin video from being reported as a generic media-tool failure solely because it was copied from the
  featured feed.
- A live probe of the reported URL now reaches the Douyin extractor and returns the bounded `AUTH_REQUIRED` guidance
  when no fresh Netscape cookie export is selected. Plugin version is `0.13.1`.

## 2026-09-09 concise model-generated Feishu results

- Full knowledge remains persisted for Desktop VKC, while every new analysis now makes one additional Hermes structured
  request over the complete validated bundle and stores a 600-character-bounded `notification_summary` in the summary
  document. The prompt requires a 300–600 Chinese-character synthesis spanning the beginning, middle, and end.
- Feishu terminal rendering sends only title, author, duration, the model digest, authoritative knowledge timeline, and
  trace IDs. Chapters, knowledge points, and suggested Q&A remain available in Desktop instead of expanding the chat
  notification. If digest generation fails, analysis still succeeds and the renderer uses a 900-character safe fallback.
- Notification summarization is a distinct progress step. Analysis prompt/fingerprint version is `1.3.0`, and plugin
  version is `0.13.0`. The previously affected 21:58 video was summarized directly from its complete 18/24/12 result;
  the generated 713-character digest was persisted as summary version 2 for short re-delivery.

## 2026-09-08 Feishu terminal notification timeline coverage

- Workflow `workflow_01788826461635535800_9f81878d00` downloaded the complete 21:58 media and produced 849
  transcript segments through 21:54. Its persisted knowledge was also complete: 18 chapters through 21:30, 24 points
  through 21:51, and 12 Q&A items through 21:43.
- The apparent four-minute analysis was a notification rendering defect. The renderer selected only the first 5
  chronological chapters, first 5 points, and first 3 Q&A items, and truncated the summary at 900 characters. It now
  emits the complete bounded KnowledgeService result (18/24/12 and an 8,000-character summary), relying on the existing
  stable multipart packer when needed.
- A regression requires the summary ending and final 21-minute citations to survive rendering. The affected persisted
  result renders in one 5,378-character Feishu-safe part with final chapter, point, and Q&A ranges present; no media,
  transcript, or model reanalysis is needed.

## 2026-09-07 Feishu VKC stage 7

- The live profile was backed up with SQLite online backup and SHA-256 manifests, migrated explicitly to schema head
  `20260907_0010`, and released with messaging enabled for one verified Feishu user. Allow-all remains false and group
  admission remains allowlist-only.
- Real DM, group mention, and group-topic requests created trusted subscriptions. Cached success, bounded Bilibili 412
  failure, terminal delivery, retry delivery, and pending-Outbox recovery after Gateway restart all reached Feishu;
  the final Outbox backlog is zero.
- Topic events now keep their immutable inbound message ID separate from the topic reply anchor. This prevents a topic
  collection from reusing the top-level group's idempotency key while preserving delivery to the original topic.
- Explicit Chinese collection intent containing exactly one allowed Bilibili URL is persisted before any model round
  trip. Idempotent replays of the real group and topic events completed persistence plus Feishu API delivery in 966 ms
  and 646 ms, reused their expected workflows, and created no duplicate tasks.
- Full verification includes the complete Feishu adapter suite. The remaining operational limitation is external:
  anonymous Bilibili probes return 412 until the operator configures a lawful cookies export; Hermes reports this as a
  bounded, redacted `RATE_LIMITED` failure rather than falling back silently.

## 2026-09-07 Feishu VKC stage 6

- Messaging collection now accepts only exact Bilibili on-demand URLs and b23 short links. The Worker validates URL
  shape and every DNS answer before yt-dlp, validates each short-link redirect with a five-hop cap, and validates the
  probed platform, final URL, and DNS again before download. Private, local, link-local, reserved, mixed-answer, forged
  platform, and forged redirect targets are rejected with a stable `UNSAFE_URL` code.
- Admission enforces profile-local user and chat daily/active-workflow quotas, the existing 30-minute/720p messaging
  limits, and 2 GiB storage reserve both before job creation and immediately before download. Gateway bot admission,
  ACL, trusted-origin isolation, and synthetic-user rejection are included in the full verification set.
- Messaging PII defaults to 90-day retention and is removed only for terminal workflows whose Outbox has drained.
  Periodic cleanup also removes only expired `app.db.*.bak` migration backups beside the active database and never
  user media. Structured logs redact credentials, cookie arguments/paths, and signed query values, including formatted
  exceptions. Platform/auth/rate/storage/model failures have bounded safe user guidance.
- Full verification passed with 205 VKC tests, 144 Gateway tests, one Windows installer test, Desktop typecheck/lint,
  and 29 Vitest cases. A fixed public Bilibili BV URL passed live DNS admission. No migration was added; schema head
  remains 0010. Gateway and Worker restarted on the new code with Feishu/webhook connected and one dispatcher active;
  the live database had zero workflows/pending Outbox and about 1438.7 GiB free. Messaging ingress remains default-off
  pending stage 7 real Feishu smoke.

## 2026-09-07 Feishu VKC stage 5

- Messaging status, cancel, and the new retry tool accept an optional workflow ID. When omitted, the service resolves
  only the most recent subscription for the trusted profile/platform/user/chat/thread context, enabling natural
  “刚才的视频” requests without exposing authority fields to the model.
- Subscribers may query; only the original workflow owner may cancel or retry. Cancellation still uses
  `JobStateMachine.request_cancel`. Retry accepts only FAILED workflows, is idempotent once requeued, and never deletes
  media or existing knowledge.
- Revision `20260907_0010` adds a workflow terminal generation. Each real manual retry gets a distinct terminal Outbox
  identity, while duplicate projection/reconciliation remains idempotent. Outbox snapshots preserve the prior terminal
  status, safe code, stage, and media ID if retry begins before that notification is delivered.
- Status results now include a bounded progress value, retry availability, and deterministic Chinese UX text. Failure
  notifications include natural-language and explicit-ID retry instructions. Progress events remain quiet; optional
  Feishu action cards are intentionally deferred until a token-backed second iteration.
- Full verification passed with 181 VKC tests, 120 Gateway tests, one Windows installer test, Desktop typecheck/lint,
  and 29 Vitest cases. The live profile migrated to 0010 and restarted with Feishu, webhook, and one VKC dispatcher
  active. Its workflow and pending Outbox counts were zero, so deployment did not send a synthetic Feishu message.

## 2026-09-06 Feishu VKC stage 4

- Hermes Gateway now starts one transport-neutral `NotificationDispatcher` for every served profile that has an
  initialized VKC database. It claims the transactional Outbox only while that profile's Feishu adapter is available,
  renews a separate notification lease, and stops before adapters disconnect. Gateway restart reconciliation resumes
  abandoned delivery without starting a second VKC Worker.
- Terminal notifications preserve the trusted subscription chat, thread, and original message. Feishu topic reply
  failures keep the existing no-top-level-fallback safety rule. Each deterministic result part derives a stable UUID v5
  from its Outbox part key, so Feishu SDK retries and later Outbox retries reuse the same request identity.
- Success, degraded, failure, and cancellation templates are rendered directly from bounded structured records. Model
  text is whitespace-normalized, truncated, and Markdown-escaped; fallback ranges are explicit; failure text excludes
  raw Job errors, paths, credentials, and command output. Permanent original-target failures send only a metadata-safe
  operational alert to the configured Feishu home channel.
- No schema migration was needed beyond stage 3 revisions 0008/0009. Stage 5 remains responsible for conversational
  status/cancel/retry UX.
- Full verification passed with 177 VKC tests, 120 Gateway tests, one Windows installer test, Desktop typecheck/lint,
  and 29 Vitest cases. The live profile remained on schema 0009 with an empty Outbox; after restart Gateway reported
  one active VKC notification dispatcher and two connected platforms without sending a synthetic Feishu message.

## 2026-09-06 Feishu VKC stage 0

- Added unregistered collect/status/cancel argument contracts, default-off messaging admission settings and bounded
  operator limits; Desktop ingest is unchanged. Manifest now matches all five registered read-only tools.
- Recorded command semantics, fixed Bilibili fixture, simulated Feishu adapter coverage and baseline checks in
  `docs/feishu-vkc-stage0.md`. Live metadata probe returned RATE_LIMITED; no real Feishu message was sent.
- Feishu tests now use a temporary profile even when clearing environment variables, and the direct DNS rebinding
  test excludes Windows registry proxies. All 76 Feishu cases pass; 37 new contract cases and Desktop 27 tests pass.
- Stage 1 remains required to register the new tools and carry trusted origin/authorization through dispatch.

## 2026-09-05 Ark reasoning compatibility repair verification

- After JSON format retry was repaired, GLM-5.3 also rejected `reasoning_effort=none`. Gateway now exposes the
  explicit capability rejection and VKC performs one bounded retry with low reasoning effort, retaining JSON mode,
  output limits and local validation. The backend was restarted and the requested video was reanalyzed.
- Job `job_01788587898841964100_50797dbac6` completed successfully. Version 6 has zero degraded ranges, replacing
  the all-fallback version 5. The combined Gateway/VKC tests passed (227 tests at that point).

## 2026-09-05 structured-format retry with provider errors in reply text

- The latest GLM-5.3 analysis of the Hermes Agent tutorial produced eight fallback ranges. All 18 map/reduce
  attempts were rejected with HTTP 400 because the configured Ark Agent Plan endpoint does not support
  `response_format.type=json_schema` for this model.
- The Agent returned the provider diagnostic in both `error` and a non-empty `final_response`. Gateway previously
  emitted `response_format_unsupported` only when `final_response` was empty, so it returned HTTP 200 and VKC
  attempted to parse the diagnostic as JSON instead of activating its existing `json_object` compatibility retry.
- Failed/incomplete structured requests now emit the capability error even when reply text contains a diagnostic.
  Ordinary partial-output behavior is preserved. No API schema or persistence migration is required.
- Verification: 125 Gateway/client tests passed, including empty/non-empty diagnostic regression cases and a real
  loopback HTTP test from HermesClient through Gateway that verifies 502 -> json_object retry -> 200. A direct
  request to the configured Ark GLM-5.3 endpoint also returned valid JSON using `json_object`.
- The running Hermes backend must reload this change; existing fallback documents require forced reanalysis.

## 2026-08-30 add-content storage-location guidance

- Both the content-link and local-video modes now display the effective global media-asset storage root before the
  source-specific fields. The location is read-only on this page and shares the same cached `/system/storage` query
  as System Settings.
- The notice recommends choosing a spacious disk before the first import, explains that video, thumbnails, ASR audio,
  and Transcript files use the shared root, and provides a direct action that switches to System Settings. Storage
  changes and verified migration remain available only from System Settings.

## 2026-08-30 Desktop live-monitor cancellation latency repair

- A reported `RECORD_LIVE` cancellation appeared ineffective because the Desktop request timed out after 15 seconds.
  The persisted job did eventually transition from `WAITING_LIVE` to `CANCELLED`, and its source was disabled, so the
  live state machine itself was working.
- The actual bottleneck was the Desktop plugin event socket after restart: with no event cursor it replayed all 33,837
  persisted job events in 100-event batches. The long-running monitor alone had about 1,485 events. Serial JSON sends
  occupied the Hermes HTTP event loop for minutes, causing cancellation and ordinary reads to queue and time out.
- The Desktop-only `/events` notification socket now snapshots the latest persisted event ID when no reconnect cursor
  is supplied and listens only for subsequent changes. Explicit-cursor catch-up and the standalone FastAPI `/ws`
  history-replay contract remain unchanged.

## 2026-08-30 configurable media storage and verified migration

- The former “ASR 设置” tab is now “系统设置”. It exposes the effective global media storage root while retaining
  the existing faster-whisper and runtime settings on the same page.
- Changing the root starts a background migration only after all collection/analysis jobs are terminal. The Desktop
  shows byte/file progress across copy and SHA-256 verification, and blocks task mutations until migration finishes.
- Migration stops the Worker, copies video, thumbnails, ASR audio, transcripts, and other relative media assets into
  an empty target directory, verifies every file, persists the new root, restarts the Worker with that root, and only
  then removes the old asset directory. A copy/verification/switch failure leaves the old root configured and usable;
  an old-directory cleanup failure is reported as a warning without rolling back the successfully switched root.
- The SQLite database remains under the Hermes profile `video-knowledge/data` directory. A regression test registers
  a real media item and confirms its existing media ID resolves and plays from the new root after migration.

## 2026-08-30 expandable media-library player

- The media-library player no longer depends on Electron exposing the native HTML video fullscreen control. An
  explicit `放大播放` action expands the existing video element over the application work area, preserving playback
  position and play/pause state instead of mounting a second player.
- Users can exit with the toolbar action, the backdrop, or Escape. Selecting/deleting another media item also closes
  the expanded player so an obsolete playback surface cannot cover the library.

## 2026-08-30 per-link YouTube Cookies selection

- “添加内容”首次识别链接若收到稳定的 `AUTH_REQUIRED` 错误，会在链接输入框下方展开 Netscape
  `cookies.txt` 文件选择；普通公开链接不会显示该控件。更换链接会清空旧路径，避免凭据误用于其他来源。
- 用户选择的文件只随当前 probe 和 INGEST_VIDEO 任务传递。后端会验证文件存在、大小、UTF-8 文本及
  Netscape 头；Worker 优先使用任务级 Cookies，未选择时仍回退到全局配置。`JobRead` 会删除
  `cookies_file`，所以路径不会出现在任务中心或 API 任务响应中，日志也不会记录 Cookies 内容。
- YouTube 携带 Cookies 时，probe、字幕下载和媒体下载统一增加经本机验证可用的
  `youtube:player_client=default,web_embedded`、Node JS runtime 与 `ejs:github` remote component 参数。
  实际探测 `06rHoEpiuYY`（首字符为数字 `0`）成功；它与此前失败的 `O6rHoEpiuYY`（字母 `O`）
  是两个不同的视频 ID。

## 2026-08-30 unavailable-video error classification

- yt-dlp may append generic browser-Cookies advice to unrelated YouTube failures. The media adapter now classifies
  an explicit `video is unavailable`/removed/region failure before authentication hints and returns the stable
  `MEDIA_UNAVAILABLE` code instead of incorrectly reporting `AUTH_REQUIRED`.
- Video Knowledge inline errors now unwrap the Desktop IPC and plugin API envelopes and display the safe backend
  message rather than the raw `Error invoking remote method ... 422 ...` payload.
- The reported YouTube ID returned `This video is unavailable` from the runtime yt-dlp and HTTP 404 from YouTube's
  oEmbed endpoint. No `VKC_YT_DLP_COOKIES_FILE` is configured in the current development runtime, but Cookies alone
  cannot make a deleted, inaccessible private, or region-blocked video publicly available.

## 2026-08-30 provider response-format compatibility

- A 16:17 Xiaomi O3 reanalysis selected `deepseek/deepseek-v4-flash`. The provider rejected every map and reduce
  request with HTTP 400 `This response_format type is unavailable now`; Hermes Gateway surfaced the provider
  failure and all eight map chunks consequently used transcript fallback even though the model service stayed up.
- Structured analysis still prefers provider-enforced `json_schema`. When and only when the provider explicitly
  reports that `response_format` is unavailable/unsupported, Gateway emits a safe machine-readable capability code
  and the VKC client performs one compatibility retry with `json_object` plus the identical JSON Schema in the trusted
  system message. Gateway also adapts known DeepSeek `json_schema` requests directly to its supported `json_object`
  constraint after resolving the actual provider, avoiding the rejected request entirely. Hermes structured mode,
  reasoning disablement, output bounds, strict Pydantic validation, and authoritative citation validation remain in
  force. Unrelated gateway or network failures do not activate the compatibility path.
- The analysis contract/fingerprint version is `1.2.2`, so a non-forced run cannot reuse the all-fallback `1.2.1`
  documents. Runtime repair version 7 completed with 18 chapters, 24 knowledge points, 12 suggested Q&A entries, zero
  degraded ranges, and zero provider format-rejection dumps.

## 2026-08-30 reanalysis model selector

- The media-library Hermes result toolbar now places the shared Hermes `ModelCatalogMenu` beside `重新分析`. It defaults
  to the provider/model pair saved on the media's original automatic ANALYZE job from Add Content; an original null
  pair is displayed as `Hermes 全局模型`.
- Users can select another provider/model or return to the global model before reanalysis. The selection is sent only
  as that forced ANALYZE job's `analysis_provider`/`analysis_model`; it does not change Hermes global model settings.

## 2026-08-30 empty cited analysis retry

- A valid top-level Hermes JSON object with a summary but empty knowledge arrays previously bypassed structured retry:
  `_generate_bundle` accepted it, then `_generate_map_bundle` immediately used transcript fallback. This caused the
  final 41-segment chunk of the 16:17 Xiaomi O3 video (`14:47.420` through `16:12.600`) to be marked degraded after
  one short, non-truncated model response even though llama-server remained healthy.
- Model-facing analysis schemas now require at least one chapter, knowledge point, suggested Q&A item, and citation
  segment ID. A provider that does not enforce the schema is still protected by a post-normalization cited-content
  check, which sends the existing corrective second request before fallback is allowed.
- The analysis contract/fingerprint version is `1.2.1`. Existing persisted results remain readable; reanalysis creates
  a new version under the corrected contract.

## 2026-08-29 visible Hermes fallback ranges

- A map chunk that falls back after an invalid Hermes structured response now records system-authored degradation
  metadata: `degraded=true` on retained fallback entries and a top-level `degraded_ranges` item containing the full
  affected chunk citation, chunk index, and stable `model_invalid_response` reason. The metadata is excluded from the
  model JSON schema so generated content cannot forge or suppress it.
- Successful global reduce output retains all map-level degradation ranges even when it rewrites the fallback entries.
  The summary knowledge document persists the overall flag and exact ranges; category documents retain per-entry flags.
- The Desktop knowledge view shows an amber warning, clickable affected ranges, dedicated fallback timeline markers,
  and badges on overlapping entries. Existing `Transcript section` / `Transcript evidence` fallback documents are
  recognized client-side, so legacy results get best-effort warnings without reanalysis.
- Normal boundary evidence supplementation is not treated as degradation. The analysis output contract is version
  `1.2.0`.

## 2026-08-29 duration-adaptive Hermes analysis chunks

- Hermes map analysis no longer uses a fixed 48-segment batch. It derives the target from authoritative Transcript
  timestamps: up to 5/15/30/60/120 minutes use 32/40/48/64/80 segments, and longer transcripts use 96.
- `VKC_ANALYSIS_MAX_CHUNK_SEGMENTS` now defaults to 96 and remains a hard operator ceiling. The existing 12,000-
  character limit independently closes a chunk early for dense subtitles, preserving bounded prompts and 64K context.
- The adaptive strategy, effective segment limit, and character cap are included in the knowledge fingerprint so
  results produced under fixed-48 chunking are never mistaken for adaptive-plan cache hits.
- Existing-library projection shows representative 60-minute transcripts dropping from 30–42 map chunks to 22–32,
  a 68-minute transcript from 22 to 15, and a 121-minute transcript from 46 to 23. Short videos retain finer batches.

## 2026-08-29 per-content Hermes analysis model

- “添加内容”的 faster-whisper 配置下方新增 Hermes 知识分析模型选择器，直接复用 Desktop SDK 的
  `ModelCatalogMenu`。默认继承 Hermes 全局模型；清除覆盖值即可恢复继承。
- 选择值以 `analysis_provider` 和 `analysis_model` 成对写入当前采集任务，并沿普通视频、本地视频、
  直播录制后处理和自动 ANALYZE 任务传递。它不会调用全局模型切换接口，也不会改写 Hermes 配置。
- Hermes Client 将任务级 provider/model 作为单次 OpenAI-compatible 请求覆盖发送；未选择时继续使用
  `model=hermes-agent`，由 Gateway 解析全局默认模型。知识文档模型标识和分析指纹包含任务级选择。
- Verification passed: 88 Video Knowledge tests, 21 Desktop Video Knowledge Vitest tests, Desktop typecheck,
  plugin ESLint, and Ruff.

## 2026-08-29 non-streaming analysis cancellation propagation

- ANALYZE pause/cancel already stopped the durable Worker task, but its non-streaming Hermes HTTP request could
  survive as an orphan: aiohttp does not automatically cancel a non-streaming handler when the client disconnects,
  and the Gateway agent continued running in its executor thread until llama.cpp finished generating.
- The OpenAI-compatible Gateway now monitors the request transport while a non-streaming agent turn runs. A closed
  client connection hard-interrupts the live agent, aborts its request-local provider connection, and reaps abandoned
  turn processes. A cancellation event also closes the race where the client disconnects while the agent is still
  being constructed.
- Targeted verification passed: 112 API-server tests, 14 disconnect/cancellation tests, and the combined Gateway plus
  VKC analysis-control selection (16 tests). Runtime restart left llama.cpp idle after the previously cancelled job.

## 2026-08-25 Windows first-launch install-stamp repair

- Hermes Desktop 0.17.0 generated schema-v2 `install-stamp.json` files, but the packaged runtime still accepted only
  schema v1. Fresh installs therefore discarded valid release metadata and failed before running `install.ps1` with
  `no SOURCE_REPO_ROOT and no install stamp`.
- The runtime now accepts schema v2 and preserves its validated `repository` field, so VKC releases bootstrap from
  `yknife/hermes-agent` instead of silently falling back to the NousResearch upstream repository.
- Unit coverage verifies v2 parsing and fork retention. Packaged-app and RC verification now require the exact runtime
  schema plus a usable repository. A replacement `Hermes-0.17.0-win-x64.exe` was built and RC verification passed.
- A second-machine install then exposed a legacy `.env` collision: a persisted `HERMES_DASHBOARD_SESSION_TOKEN`
  overrode Desktop's fresh per-spawn token, so the backend bound successfully but readiness returned HTTP 401.
  Desktop now atomically removes only that obsolete persisted entry before local backend launch, while the Python env
  loader preserves a parent-injected token as the long-term defense. Other user settings and secrets remain unchanged.

## 2026-08-24 Sprint 10 Windows release candidate

- Windows RC packaging reuses the single Hermes Desktop Electron Builder NSIS/MSI pipeline. The retired standalone
  VKC PyInstaller process is intentionally not restored; React ships in `app.asar`, while the Hermes-managed Python
  checkout/venv remains the only Gateway and Worker runtime.
- Install stamps now carry a validated GitHub `repository`, branch, and immutable commit. VKC builds bootstrap from
  `yknife/hermes-agent:vkc-integration` instead of trying to fetch the fork-only commit from NousResearch upstream.
- `scripts/build-rc.ps1` produces verified installers, SHA-256 records, `install-stamp.json`, and a machine-readable
  release manifest. A manual/tag-triggered Windows GitHub workflow uploads the verified artifact set.
- `/system/runtime` and the ASR settings page report safe versions for yt-dlp, streamget, faster-whisper, FFmpeg, and
  ffprobe without exposing executable paths. Existing Hermes supervision, model download, update, and data-preserving
  uninstall flows remain authoritative.
- Added the Windows RC user guide, troubleshooting guide, packaging ADR, and release/VM acceptance checklist.

## 2026-08-23 bounded llama.cpp structured knowledge analysis

- Structured Hermes Gateway calls now forward the caller's `response_format` to the provider, allowing llama.cpp to
  enforce JSON Schema grammar instead of treating the schema only as prose.
- The local Custom/Qwen provider disables llama.cpp thinking with
  `chat_template_kwargs.enable_thinking=false`; `reasoning_effort=none` and Ollama's `think=false` alone were ignored
  by the current llama.cpp build and exhausted the 4096-token output budget on hidden reasoning.
- Knowledge map prompts use compact `s1...sN` citation aliases, restore authoritative database IDs before validation,
  cap each map chunk at 24 transcript segments, and apply JSON Schema `maxItems`/`maxLength` bounds. Map and reduce
  coverage checks prevent a schema-valid response from silently dropping input chunks.
- Runtime regeneration of 《张！嘴！》 completed successfully as knowledge version 7, with 7 chapters, 12 knowledge
  points, 7 suggested questions, citations from 0 through 206.06 seconds, and no new `finish_reason=length` event.
  Unsupported bracketed work titles are removed when they do not occur in the transcript. Relevant verification
  passed with 210 tests.

## 2026-08-23 live monitor cancellation and event compaction

- Cancelling a `RECORD_LIVE` task now disables its persisted live source before cancelling the durable job, so the
  monitor cannot be re-queued. Retrying the cancelled task re-enables the source and resumes monitoring.
- The task center collapses consecutive offline polling cycles (`release -> claim -> probe -> wait`) into the latest
  monitor event, while persisted audit events, recording transitions, failures, and user actions remain intact.
- Full verification passed with 69 VKC tests, 115 Gateway tests, Desktop typecheck, ESLint, Ruff, formatting, and four
  Desktop API tests.

## 2026-08-23 task center daily scope and media ownership

- The task center defaults to jobs created since Beijing midnight plus active long-running `RECORD_LIVE` monitors,
  regardless of monitor creation date. Users can switch back to the complete history and combine either scope with
  the existing status filter.
- Job API responses now include their persisted `source_id` and `media_id`. Task cards resolve ownership through the
  media library, live sources, and finally the input URL so completed, in-progress, and pre-media jobs are identifiable.
- Full verification passed with 68 VKC tests, 115 Gateway tests, Desktop typecheck, ESLint, Ruff, formatting, and four
  Desktop API tests.

## 2026-08-23 persistent ASR model download state

- faster-whisper model downloads are coordinated by a process-wide registry. Concurrent requests for the same model
  reuse one task, and cancelling a page request no longer cancels the underlying Hugging Face download.
- `/system/asr` exposes `models[].downloading`; the ASR settings page restores that state after navigation, polls
  while a download is active, and disables the duplicate download action.
- Regression coverage simulates an abandoned page request and verifies the download continues and the downloader is
  invoked exactly once. The full verification suite passed with 67 VKC tests, 115 Gateway tests, Desktop typecheck,
  ESLint, Ruff, formatting, and four Desktop API tests.
- The local `large-v3-turbo` cache completed successfully (about 1.62 GB), and Hermes was restarted with the fix.

## 2026-08-23 unified video/live content entry

- “直播订阅”独立页面已移除；“添加内容”是视频与直播间的统一入口，创建成功后统一进入任务中心。
- `/sources/probe` 现在返回 `source_type=VIDEO|LIVE`。已知直播间 URL 由 URL 结构分类并用 StreamGet
  获取当前开播状态；普通视频继续使用 yt-dlp，yt-dlp 识别出的正在直播内容也会切换为 LIVE。
- 添加页在识别前只展示链接输入；识别后，普通视频显示画质与字幕优先级，直播显示轮询间隔、
  录制上限与画质。ASR 模型/设备/精度/语言/VAD/词时间戳和自动知识分析为公共配置。
- 右侧只展示当前链接的类型、平台、标题、作者、开播状态或视频字幕详情，不再承载订阅列表。
- Full verification passed with 57 VKC tests, 114 Gateway tests, Desktop typecheck/Vitest, Ruff, formatting,
  ESLint, and lock consistency. Hermes was restarted with the updated probe contract.

## 2026-08-23 live end-of-stream recovery repair

- The first real Bilibili live smoke test exposed three coupled failures: reconnect progress could move backward by
  a fraction after ffprobe reconciliation, retrying an offline room ignored valid segments from the previous attempt,
  and one long `RECORD_LIVE` job blocked the single Worker from claiming other subscriptions and post-processing.
- Live progress is now monotonic and persisted at most once per recorded second. A retry discovers valid
  `segment-*.part.mkv` files through the unfinished live session, adopts the session, and finalizes it even when the
  room is already offline. Paused recordings become `INTERRUPTED` instead of remaining falsely `RECORDING`.
- Long live recordings now execute as supervised background tasks while the main durable queue continues processing
  monitoring, ASR, and analysis jobs. Lease, cancellation, retry, and state-machine writes remain unchanged.
- Runtime recovery validated the real 极客湾 recording: a 354.787-second, 66,932,456-byte segment was remuxed and
  registered as media `media_01787415981429975600_8bda6ee198`; ASR produced a Transcript and automatic analysis job
  `job_01787416011655339600_2bd11507b7` reached `SUCCEEDED` with four READY knowledge documents.
- Full verification passed with 56 VKC tests, 114 Gateway tests, Desktop typecheck/Vitest, Ruff, formatting, ESLint,
  and lock consistency.

## 2026-08-23 live recording event display compaction

- 任务中心会把一段连续直播录制产生的逐秒 `job.progress` 事件折叠为最新一条，展示最新录制秒数、
  进度和北京时间。状态转换、断流/重连边界、失败以及后续处理阶段仍独立展示。
- 底层持久化事件没有被删除或改写，Worker 审计和状态机恢复语义保持不变。

## 2026-08-22 Sprint 8 live monitoring and recording

- Hermes Desktop 的“视频知识”侧边栏新增“直播订阅”页面，可添加、暂停、恢复和立即检测直播来源，
  并展示监控任务、最近检测时间和最近场次状态。
- 后端新增直播来源 API、`live_sessions` 持久化场次表和 `RECORD_LIVE` Worker pipeline。
  离线来源进入可调度的 `WAITING_LIVE`；开播后按场次 key 去重，避免重复启动同一场录制。
- `StreamGetAdapter` 使用固定版本 `streamget==4.0.9` 解析 Bilibili、Douyin、Douyu、Huya、
  Twitch 和 YouTube 直播。签名流地址仅在媒体适配器内存和 FFmpeg 参数中使用，不进入任务、
  数据库、错误或日志。
- FFmpeg 以 Matroska 分片录制，断流时保留非空分片并最多快速重连三次；录制结束后无损合并、
  ffprobe 校验并登记原始分片和最终媒体。最终媒体自动创建本地 `INGEST_VIDEO` 后处理任务，
  复用现有 ASR、Transcript 和 Hermes 知识分析链路。
- Sprint 8 自动化验证覆盖直播来源去重、StreamGet 状态映射、断流分片保留和桌面类型检查。
  真实平台 smoke test 仍取决于平台网络可达性、风控/Cookies 和实际开播窗口。
- `scripts/check.ps1` 全量通过：54 项 VKC tests、114 项 Gateway tests、3 项 Desktop Vitest，
  以及 Ruff、格式、ESLint、Desktop TypeScript 和 uv lock 一致性检查。Hermes 已重启，运行 profile
  已迁移至 `20260822_0006`，`live_sessions` 表和受监管 VKC Worker 均已生效。

## 2026-08-22 task-center Beijing time

- Task event timestamps are displayed explicitly in `Asia/Shanghai` (`UTC+8`). SQLite/API datetimes without a
  timezone suffix are treated as UTC before conversion, avoiding the previous eight-hour error on Beijing hosts.
- The formatter also normalizes offset-aware timestamps and returns a safe placeholder for malformed values.

## 2026-08-22 local media seek repair

- Transcript and Hermes knowledge timeline clicks already supplied the correct millisecond offset, but the Electron
  `hermes-media://stream` handler delegated local byte-range reads to `net.fetch(file://...)`. The existing test only
  asserted that the `Range` header was forwarded and did not prove that the local response was actually partial.
- Local playback now serves files directly as Range-aware streams with `Accept-Ranges`, `Content-Range`,
  `Content-Length`, media MIME types, `206` responses, `HEAD` support, and `416` handling for invalid ranges.
- Runtime verification after restarting Hermes: clicking `0:02` in both the Transcript timeline and Hermes knowledge
  timeline moved the real media element to approximately `3.3s` while playback continued.

## 2026-08-22 structured-response reliability repair

- A new analysis job failed at 10% with `HERMES_INVALID_RESPONSE` because the
  local model returned syntactically valid JSON without a usable top-level
  knowledge summary. The transcript itself was valid UTF-8; apparent mojibake
  during diagnosis came from PowerShell's default output decoding.
- `KnowledgeService` now unwraps only known result envelopes and retries a
  semantically invalid structured response once with an explicit root-shape
  correction. Strict Pydantic and transcript citation validation still run on
  every accepted response. Completed map steps are not discarded.
- The analysis prompt version is `1.0.1`; the retry count is configurable with
  `VKC_ANALYSIS_STRUCTURED_ATTEMPTS` and defaults to two total attempts.
- Runtime verification: retried job `job_01787358012404067600_a885212bd0`
  reached `SUCCEEDED`/100% on attempt 2. Four READY documents were stored: one
  summary, 10 chapters, 14 knowledge points, and 9 suggested Q&A items.

## 2026-08-22 Hermes knowledge-result runtime repair

- Hermes Desktop now owns an authenticated loopback OpenAI-compatible API-server adapter in the dashboard lifespan. The adapter and the supervised VKC worker use the same process-local key; an environment key takes precedence over a stale persisted secret.
- VKC bypasses Windows system proxy discovery for loopback Hermes URLs. Remote Hermes URLs retain normal system-proxy behavior.
- Chat Completions preserves `response_format.json_schema` as an ephemeral agent constraint. VKC requests explicit `structured_mode`, which still uses the configured Hermes provider/model/runtime while omitting unrelated project context files and tools.
- Local-model calls use a 600-second timeout so the final reduce does not create orphan retries after a premature 180-second timeout.
- Model JSON parsing selects the last outermost object, applies a narrow field whitelist/normalization, then performs strict Pydantic validation. Citation IDs are filtered against the current transcript, untraceable items are dropped, and citation time ranges are derived from authoritative segments.
- Analysis progress is persisted after every map/reduce step instead of appearing stuck at 10%.
- Runtime verification: job `job_01787319051803896900_87f6ce14fd` reached `SUCCEEDED`/100%; four READY documents were stored (summary, 13 chapters, 9 knowledge points, 6 suggested Q&A items).
- Full `scripts/check.ps1` verification passed: 49 VKC tests, 114 Gateway tests, Desktop typecheck, plugin Vitest, Ruff, formatting, ESLint, and uv lock consistency.

更新时间：2026-08-21

## 当前目标与架构

- Hermes Desktop 是唯一用户入口；VKC 不再单独启动 Web 或 API。
- VKC 是 Hermes 默认启用的“视频知识”侧边栏，路由为 `/video-knowledge`。
- VKC REST API 注册在 Hermes `gateway/platforms/api_server.py`，前端通过插件命名空间访问，
  与 Hermes 共用网关、认证和 profile。
- Hermes 启动时按 profile 执行 VKC 数据库迁移，并自动拉起、监管和停止 VKC Worker。
- 活动前后端代码全部位于 `thirdparty/hermes-agent`；旧独立工程仅归档，不参与运行或打包。

## 关键目录

- Desktop UI：`thirdparty/hermes-agent/apps/desktop/src/plugins/video-knowledge`
- Python 后端：`thirdparty/hermes-agent/plugins/video_knowledge/backend`
- Dashboard transport：`thirdparty/hermes-agent/plugins/video_knowledge/dashboard/plugin_api.py`
- 共享 Gateway：`thirdparty/hermes-agent/gateway/platforms/api_server.py`
- VKC 测试：`thirdparty/hermes-agent/tests/video_knowledge`
- 旧工程归档：`thirdparty/hermes-agent/archive/video_knowledge_pre_migration`

## 已完成能力

- Sprint 1–5：健康状态、持久化任务状态机、租约/重试、URL 探测与去重、yt-dlp 下载、
  FFmpeg/ffprobe、字幕规范化、Transcript/FTS 搜索、faster-whisper ASR、长音频分片检查点。
- Sprint 6：Hermes 内聚、共享网关、profile 隔离、Worker supervision、Hermes Client、
  Map-Reduce 知识分析及摘要/章节/知识点/建议问答。
- Sprint 7：可信问答复用 Hermes Chat Workspace 的 Conversation/Message 持久化、流式回答和
  工具事件，VKC 不维护独立聊天界面或会话存储。“问知识库/问 Hermes”会新建 Hermes 会话并
  注入库级或单视频范围；后端提供 `search_videos`、`search_transcript`、`get_segments`
  三个 profile 内只读工具，回答中的 `video-cite` 可跳回对应视频时间点。
- Sprint 8：直播来源订阅、轮询调度、场次去重、StreamGet 解析、FFmpeg 分片录制和断流重连，
  录制完成后复用 ASR/Transcript/Hermes Pipeline，不引入独立直播处理链路。
- 侧边栏已恢复迁移时遗漏的完整交互：探测确认、画质/字幕语言、自动分析、
  tiny/base/small/medium/large-v3 模型、CPU/CUDA/精度/语言/VAD/词时间戳、任务筛选和操作、
  持久化事件 WebSocket、媒体资产、本地 Range 视频预览、Transcript 搜索与点击跳转、
  知识结果和 ASR 资源建议。
- Windows CUDA 运行库由固定版本的 NVIDIA Python wheels 提供；ASR 检测器会注册虚拟环境内的
  cuBLAS/cuDNN/NVRTC DLL 目录，不再依赖系统安装 CUDA Toolkit。RTX 5060 Ti 上已验证
  `ctranslate2` CUDA 检测、DLL 加载及 faster-whisper `small + cuda + float16` 模型加载。
- Windows 媒体下载运行器会同时解析 yt-dlp 的 stdout/stderr；下载进度默认写入 stderr，必须
  转发到 Worker 的持久化进度事件，否则长下载会在 UI 中表现为停在 10%。

## 启动与验证

```powershell
.\scripts\dev.ps1
.\scripts\check.ps1
```

- `dev.ps1` 只启动 Hermes Desktop；已有 `node_modules` 时不会因本机 npm engine 区间重复安装失败。
- 最近一次 Sprint 7 全量验证：VKC pytest 41 项、Hermes Gateway pytest 112 项、
  Desktop 现有插件 Vitest 3 项通过；新增 Chat Workspace/API 针对性 Vitest 6 项通过。
  Ruff、格式检查、ESLint、Desktop TypeScript 和 uv lock 一致性检查通过。
- Hermes wheel 已审计，包含 VKC 后端、Worker、迁移、配置、Prompt 和 Dashboard 插件资源。

## 已知本地问题与下一步

- 最近一次 Bilibili 任务在 `PROBING` 5% 阶段收到 HTTP 412，被归类为 `RATE_LIMITED`；
  不是 Hermes 模型分析失败。当前未配置 `VKC_YT_DLP_COOKIES_FILE`。
- 要验证真实视频闭环，应先配置合法导出的 Netscape Cookies，重启 Hermes 后重试采集；
  Cookies、API key 和签名地址不得写入日志或提交仓库。
- 本地 Range 播放协议、Windows 路径编码和控制器播放路径已有自动化测试，但仍需用成功下载的
  视频做一次人工画面、拖动 seek、字幕点击跳转验证。
- 本机 npm 为 11.11.0，不在 Hermes 支持区间；建议升级到 `>=11.17.0`。

## 不可回退的设计约束

- 不重新引入独立 VKC HTTP listener 或独立 React 应用。
- 不把媒体工具调用移出 `backend/media_adapters`，不使用 `shell=True`。
- 任务状态只能通过 `JobStateMachine` 修改，每次转换必须持久化 `job_events`。
- Worker 写进度或终态前必须持有有效租约。
- Transcript 属于不可信 LLM 输入；不得记录 Cookies、授权头、API key 或签名流地址。
- 问答会话、消息、流式输出与工具事件必须继续复用 Hermes Chat Workspace；VKC 只负责
  受限上下文、只读检索工具和视频引用导航。

## 2026-09-06 飞书 VKC 闭环阶段 1

- Gateway 现在为每个已准入 turn 绑定只读 `ToolInvocationContext`，可信 profile/session/platform/chat/thread/
  message/user/authorization 不进入模型参数或 prompt，并能跨工具线程传播且不会在并发 turn 之间串值。
- Video Knowledge 插件新增 Feishu 专属 `video_knowledge_messaging` 工具集，包含 `collect_video`、
  `get_collection_status` 和 `cancel_collection`。平台工具集负责会话级 Schema 隔离，handler 再次执行可信上下文
  与 profile 校验；没有使用会被进程级 TTL 缓存的 `check_fn` 做会话授权。
- revision `20260906_0007` 新增最小 `collection_requests` 受理回执。同一 platform/chat/message 在原子事务内
  复用稳定 workflow/job；采集强制自动分析并立即返回，状态和取消按原请求者隔离，取消继续走
  `JobStateMachine`。
- 消息配额、最大清晰度和最大视频时长已执行。Worker 在下载前根据 probe 拒绝未知或超限时长；Desktop
  任务没有消息时长字段，因此原采集行为不变。
- 阶段 1 验证通过：155 项 VKC 测试、110 项 Feishu/网关上下文测试、38 项聚焦测试；migration 已从
  `20260822_0006` 实际升级到 `20260906_0007` 并验证新表和索引。终态 Outbox、原会话主动推送、多订阅者
  workflow 复用和明确的 ingest/analysis 父子关联保留到阶段 2–4。完整 `scripts/check.ps1` 也已通过：
  Gateway API 118 项、Windows 安装脚本 1 项、Desktop typecheck/ESLint 和 Vitest 29 项均成功。

## 2026-09-06 飞书 VKC 闭环阶段 2

- revision `20260906_0008` 新增 `collection_workflows`、`workflow_subscriptions`、`notification_outbox`，以及
  Job 的非敏感 `workflow_id`/`parent_job_id`。旧 `collection_requests` 会迁移为 owner subscription 并恢复
  已有 ingest/analysis 关联；升级和回滚均已实际验证。
- 消息采集按入站消息幂等，并让不同用户对同一活动 Source 共享 workflow/job、保留独立订阅。首个订阅者是
  取消 owner；后来订阅者不能中断共享任务。READY 知识直接生成完成态 workflow 和稳定 PENDING Outbox，
  不重新下载或分析。
- `JobStateMachine` 在状态事务中同步 workflow；analysis 子任务原子创建或复用，并传播 workflow/父任务。
  ingest 成功到 analysis 成功之间保持 `ANALYZING`，失败、取消、重试和进程重启后的关联均可恢复。
- Windows 的 `time_ns()` 可能在同一时钟刻度返回相同值，旧 ID 的随机后缀会让事件游标字典序偶发倒退。
  `new_id` 现在用锁保护进程内严格递增的时间前缀；游标顺序测试连续 10 次通过。
- 完整 `scripts/check.ps1` 通过：160 项 VKC、118 项 Gateway API、1 项 Windows 安装测试、Desktop
  typecheck/ESLint 和 29 项 Vitest 均成功。通用终态 projector、Outbox 租约/退避/reconciliation 与实际
  飞书投递仍属于阶段 3–4。

## 2026-09-06 飞书 VKC 闭环阶段 3

- Job 终态事务现在同步投影 workflow，并按订阅用稳定唯一键写入终态 Outbox；ingest 到 analysis 的中间窗口
  不会提前生成成功通知，重复投影或 reconciliation 不会创建重复记录。
- 独立 `OutboxService` 提供 claim/heartbeat/acknowledge/fail/release_due。SQLite 领取使用即时写事务避免
  并发双领；过期租约可恢复，临时错误采用有上限指数退避，认证/授权/失效目标等稳定错误进入 `DEAD`。
- revision `20260906_0009` 新增不含凭据和原始异常文本的 `notification_outbox_events`，并回填阶段 2
  已有 Outbox 的 queued 事件。错误码在持久化前执行严格白名单清洗。
- 每个 profile runtime 在数据库迁移后、Worker 启动前执行 reconciliation，释放崩溃遗留的领取并补齐终态
  workflow 缺失的 Outbox。Gateway dispatcher 和飞书渲染仍属于阶段 4。
- 完整 `scripts/check.ps1` 通过：167 项 VKC、118 项 Gateway API、1 项 Windows 安装测试、Desktop
  typecheck/ESLint 和 29 项 Vitest 均成功。

## 2026-08-23 live media thumbnail generation

- Live finalization now asks the FFmpeg media adapter for the first decodable video frame, scales it to at most
  1280 pixels wide, and stores it as `source/thumbnail.jpg` with a persisted `THUMBNAIL` media asset.
- Live `media_items.thumbnail_url` points to the generated local JPEG. The Desktop media library converts local
  thumbnail paths to the existing `hermes-media://stream` protocol while leaving HTTP(S), data, and blob covers
  unchanged.
- Worker startup idempotently backfills only legacy media marked `metadata.live=true` with an empty thumbnail. It
  never modifies source recordings and records per-item failures without preventing normal queue processing.
- Runtime verification after restarting Hermes generated valid JPEG covers for all four existing live media items;
  the representative Geekwan cover is 215,159 bytes and was visually decoded successfully.
- Full `scripts/check.ps1` verification passed: 58 VKC tests, 114 Gateway tests, Desktop typecheck/Vitest, Ruff,
  formatting, ESLint, and lock consistency.
## 2026-08-23 long-live structured analysis reliability

- A 7,295-second live recording failed at map/reduce step 18/18 with `HERMES_INVALID_RESPONSE`. All 17 map calls
  had succeeded; the unbounded final reduce sent all map objects to Qwen3.5-4B and returned unusable structure twice.
- Runtime inspection also showed Hermes output-continuation overriding llama-server `--n-predict 4096`: one map
  request grew to 65,536 allowed output tokens and emitted more than 31,000 reasoning tokens. VKC structured calls
  now disable reasoning, request a configurable 4,096-token output cap, and the Hermes API gateway honors that cap.
  Structured mode disables general-chat length continuation, so the agent cannot multiply the cap to 8K/16K/32K.
- Reduce input is now deterministically deduplicated and bounded to 18 chapters, 24 knowledge points, 12 Q&A items,
  and clipped field lengths. A valid compact merge is retained when the final model response is malformed or empty.
- A map response with no cited content, or two invalid structured responses, falls back to a small verbatim transcript
  excerpt with real segment IDs. It produces a chapter, evidence item, and basic Q&A without inventing factual claims.
- Runtime repair job `job_01787449068602406100_7b8873321b` reached `SUCCEEDED`/100%. Version 2 documents are READY
  and non-empty: 18 chapters, 23 knowledge points, 12 suggested Q&A items, and one summary; all citation IDs resolve
  to the authoritative transcript. Three chapters and four knowledge points used the explicit transcript fallback.
- Full verification passed with 60 VKC tests, 115 Gateway tests, Desktop typecheck/Vitest, Ruff, formatting, ESLint,
  and lock consistency.

## 2026-08-23 live thumbnail display repair

- The generated live JPEG files and persisted paths were valid, but Electron's protected `hermes-media://` handler
  rejected `.jpg` requests with HTTP 415 because its extension allowlist contained only audio/video formats.
- The handler now permits JPEG, PNG, and WebP thumbnail assets and returns browser-readable image MIME types while
  retaining the existing protected path resolver and rejection of unrelated file extensions.
- Runtime verification after restarting Hermes showed all five local live thumbnails fully decoded in the media
  library (`complete=true`, `naturalWidth=1280`, `naturalHeight=720`).

## 2026-08-23 knowledge timeline full-duration coverage

- The 68:30 Karpathy video's READY transcript was complete through 68:28, but its version-1 knowledge documents
  stopped at 44:24. All 14 map calls had run; the old final reduce silently retained only the earlier map results.
- Compact reduce fallback now reserves chronological representatives from each map chunk, samples summaries across
  the full recording, and rejects an otherwise valid reduce response when it drops the first or final map boundary.
- A completely unparseable/truncated Hermes client response is now handled like a schema-invalid response. Non-
  retryable formatting failures use cited transcript fallback after the configured attempts; retryable transport
  failures still propagate normally.
- Runtime repair job `job_01787455296504048500_256d4c7935` succeeded. Version-2 documents contain 18 chapters,
  24 knowledge points, and 12 suggested Q&A items; chapter citations reach 67:06 and knowledge-point citations reach
  67:20, versus 44:24 previously. The final transcript segment remains complete at 68:28.
- Full verification passed with 63 VKC tests, 115 Gateway tests, Desktop typecheck/Vitest, Ruff, formatting, ESLint,
  and lock consistency.

## 2026-08-29 local media and analysis-control repair

- Consecutive `job.progress` events with the same stage and message are collapsed in the task event view, so local
  file copy progress no longer renders dozens of identical `正在导入本地视频` rows. Persisted progress and Worker
  cancellation checkpoints remain unchanged.
- New local imports extract the first decodable frame through the FFmpeg media adapter, store it as
  `source/thumbnail.jpg`, persist a `THUMBNAIL` asset, and use the local JPEG as `media_items.thumbnail_url`.
  Worker startup also backfills missing covers for legacy media marked `metadata.local=true` or `metadata.live=true`.
- The existing local one-hour media item was backfilled successfully on restart; its JPEG is 162,634 bytes and its
  database thumbnail URL now points inside the configured Video Knowledge storage root.
- ANALYZE pause/cancel now races model analysis against a 100 ms durable-control poll. Closing the Worker request is
  propagated through the non-streaming Gateway handler, which hard-interrupts the Hermes Agent and reaps abandoned
  model subprocesses instead of leaving llama-server generation on the GPU.
- The Video Knowledge sidebar contribution uses the supported `file-media` Codicon. The analysis segment cap is now
  configurable as `VKC_ANALYSIS_MAX_CHUNK_SEGMENTS` and defaults to 48 instead of 24; the supervisor forwards the
  value to its Worker process.
- The local Qwen3.5-4B llama-server was restarted with `--chat-template-kwargs
  "{\"enable_thinking\":false}"` while retaining 65,536 context and full GPU offload. Runtime `/props` confirmed
  the model/context, and a Chat Completions probe returned no reasoning content.
- Verification passed: 81 Video Knowledge tests, four job-event Vitest tests, Desktop typecheck, plugin ESLint, and
  Ruff. Hermes Desktop, Gateway, Worker, and llama-server were restarted successfully.

## 2026-08-29 selected-series knowledge Q&A

- The media-library `问知识库` action no longer stages an unrestricted whole-library chat. It opens a bounded
  checkbox selector, preselects the active video, requires at least one selection, and supports up to 50 videos for
  series-level or topic-level Q&A.
- Fresh-chat context now carries only validated `media_ids` under `scope=selected_videos`; media titles remain UI-only
  untrusted labels and are not inserted into the model prompt. The composer banner shows the selected count/titles.
- The read-only `search_videos` and `search_transcript` tools accept the selected `media_ids`. Both metadata queries
  and transcript FTS/LIKE queries apply that allowlist in SQL, so searches do not scan or return unrelated videos.
- Single-video `问 Hermes` remains available and keeps its existing `single_video` scope and citations.

## 2026-08-29 Hermes knowledge read-only tools

- The Video Knowledge toolset now registers `search_knowledge` and `get_knowledge_documents` alongside the existing
  video/transcript tools. Both query persisted `knowledge_documents` only and never enqueue or rerun analysis.
- Queries return only the latest `READY` version for each media/document type. Failed and superseded versions are
  excluded. Supported types are `summary`, `chapters`, `knowledge_points`, and `suggested_qa`.
- `search_knowledge` searches individual knowledge entries, preserves their media/title/type/version metadata, and
  emits a `video-cite` directive when the stored result contains a valid transcript citation.
- `get_knowledge_documents` accepts one media ID or a selected `media_ids` collection, supports type filtering, and
  returns structured document content and analysis metadata. Results are bounded to 20 documents, 12,000 characters
  per document, and a 48,000-character aggregate budget; truncated documents are marked explicitly.
- Fresh Video Knowledge chats are instructed to search persisted Hermes knowledge first, then use transcript tools
  to verify citations, expand details, or fill gaps. Selected-series `media_ids` scope remains mandatory.
