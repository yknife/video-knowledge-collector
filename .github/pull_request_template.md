## 变更摘要

- 

## 验证

- [ ] `uv run ruff check .`
- [ ] `uv run ruff format --check .`
- [ ] `uv run mypy apps packages`
- [ ] `uv run pytest`
- [ ] `uv run --project thirdparty/hermes-agent --extra dev pytest thirdparty/hermes-agent/tests/video_knowledge`
- [ ] `npm --prefix thirdparty/hermes-agent/apps/desktop run typecheck`
- [ ] `npm --prefix thirdparty/hermes-agent/apps/desktop exec -- eslint thirdparty/hermes-agent/apps/desktop/src/plugins/video-knowledge`

## 契约与安全

- [ ] API/schema/client 类型已同步
- [ ] 数据库变化包含迁移与 downgrade
- [ ] 日志不含 Cookie、Token、密钥或签名 URL
- [ ] 未降低测试断言或安全检查
