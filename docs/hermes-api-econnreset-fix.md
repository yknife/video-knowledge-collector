# Hermes Desktop `hermes:api` ECONNRESET 诊断

2026-09-25 的桌面日志显示 Hermes 后端于 09:33:47 UTC 退出，09:33:55 UTC 完成重新启动。此次退出与阶段 8 完成后为加载新代码进行的后端重启吻合。用户提供的 `read ECONNRESET` 没有请求路径或时间戳，不能逐字节证明属于该次重启；但当前后端健康、无连续崩溃迹象，这是一条有日志支持的高概率解释。TCP 连接在请求期间被重启的后端关闭时，Electron 的 `hermes:api` 会把原始 socket 错误直接返回给渲染进程。

修复位于 Hermes Desktop 的 Electron 主进程。对本机后端的 GET 请求，仅在 `ECONNRESET`、`ECONNREFUSED` 或 `EPIPE` 时等待一次并重新取得后端连接，再用新端口重试一次。HTTP 业务错误、远端连接、带 body/upload 的 GET 与写请求不会被自动重放。写请求若在本机后端断连时失败，错误会明确提示“可能已经完成，先检查状态”，避免用户重复提交。重试次数固定为一次。

验证：用真实 Node HTTP socket 主动复现连接重置后切换到新端口，请求恢复成功；定向测试还覆盖写请求不重放、远端/HTTP 错误不重试及第二次断连直接返回。Desktop 类型检查和 Electron lint 通过。运行中的 Electron 主进程需要重载后才会采用此修复；当前后端的 `/health` 返回 200。
