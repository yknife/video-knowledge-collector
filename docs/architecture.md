# Architecture

项目使用单仓库承载三个独立进程：Vite Web UI、FastAPI API/Coordinator 和
Python Worker。SQLite 同时承载业务数据、持久化任务队列和跨进程事件日志。

浏览器在开发环境访问 Vite `127.0.0.1:5173`，Vite 将 `/api` 代理至 FastAPI
`127.0.0.1:8000`。生产构建后可由同一受控服务托管静态资源。

共享边界见根目录 `AGENTS.md`，重大架构变化应新增 ADR。

## Sprint 2 任务引擎

- `JobStateMachine` 是唯一允许修改 Job 状态的服务，每次迁移写入 `job_events`。
- Worker 使用条件 `UPDATE ... RETURNING` 原子领取任务，并周期性续租。
- 恢复器将租约过期任务迁移至 `RETRY_WAIT`，随后调度回 `PENDING`。
- API WebSocket 从持久化事件表增量读取，因此能看到独立 Worker 进程产生的事件。
- 当前 `DemoPipeline` 仅验证编排边界；Sprint 3 将其替换为真实媒体适配器。
