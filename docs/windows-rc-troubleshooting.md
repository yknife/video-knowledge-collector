# Windows RC 故障排查

## 安装器无法下载运行时

确认可访问 `github.com`、`raw.githubusercontent.com` 和 Python 包源。检查
`%LOCALAPPDATA%\hermes\logs`，但提交日志前必须移除 API Key、Cookie、Authorization header 和
签名流地址。

## 运行环境显示 FFmpeg/ffprobe 缺失

安装 FFmpeg 并把 `ffmpeg.exe`、`ffprobe.exe` 加入 PATH，或在 Hermes `.env` 设置
`VKC_FFMPEG_PATH`、`VKC_FFPROBE_PATH` 后重启。运行环境卡片只显示版本或安全错误类型，不显示
可能包含用户名的完整路径。

## 视频平台返回 412/429

这是平台风控，不是 Hermes 模型故障。合法导出 Netscape Cookies，配置
`VKC_YT_DLP_COOKIES_FILE`，不要把 Cookies 文件、内容或路径提交到仓库。

飞书中的对应任务会经过有界重试，然后返回安全的 `RATE_LIMITED` 提示。不要关闭 Worker 或删除任务；配置合法
Cookies 并重启后，白名单用户可以发送“重试刚才的视频任务”。

## 飞书视频链接没有被受理

依次确认 Feishu adapter 已连接、发送者位于 `FEISHU_ALLOWED_USERS`、群消息已经 @机器人，并且
`VKC_MESSAGING_INGEST_ENABLED=true`。入口仍只接受 B 站点播 URL；短链重定向到其他域名、私网 DNS、超长视频、
配额耗尽或存储余量不足都会拒绝。不要设置 `FEISHU_ALLOW_ALL_USERS=true` 来绕过排查。

## 飞书已受理但没有终态结果

保持 Gateway 和 Worker 运行。检查日志中 Feishu 连接状态与 `Video Knowledge notification dispatchers active: 1`，
并检查 Outbox 是否处于 `PENDING`、`RETRY` 或 `DEAD`。Gateway 重启后会自动续投；不要删除 Outbox、workflow、
媒体或 Transcript。日志和截图在提交前仍需检查是否包含个人聊天标识。

## ASR 使用 CPU 或模型下载慢

先用 `small + cpu + int8` 完成闭环。CUDA 模式需要兼容 NVIDIA 驱动；Hermes venv 会携带所需
CUDA 用户态 DLL，不要求安装完整 CUDA Toolkit。模型下载可续用 Hugging Face 缓存。

## 中文用户名或非 C 盘安装失败

从 PowerShell 运行并保存安装日志，执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\thirdparty\hermes-agent\scripts\install.ps1 -ShowResolvedPaths
```

确认输出路径是长路径而非异常的 8.3 别名。不要移动 `%LOCALAPPDATA%\hermes` 内正在使用的数据库。

## 升级后仍显示旧版本

完全退出 Hermes（包括托盘），重新运行安装包。不要手工删除 `state.db` 或 VKC 媒体；使用内置更新
和卸载模式可保持数据一致性。
