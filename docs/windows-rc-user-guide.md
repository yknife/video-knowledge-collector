# Windows RC 用户手册

## 支持范围

- Windows 10/11 x64
- 可安装到非 C 盘和包含空格或中文的用户目录
- 默认数据目录：`%LOCALAPPDATA%\hermes`
- 默认安装方式：当前用户安装，无需管理员权限

## 安装

1. 从 GitHub Actions 或 Release 下载 `Hermes-*-win-x64.exe`、`release-manifest.json`。
2. 用 `Get-FileHash <安装包> -Algorithm SHA256` 对照 manifest。
3. 运行安装包，可选择非 C 盘目录。
4. 首次启动按引导配置 Hermes provider。安装器会准备 Git、uv、Python 和受管理运行时。
5. 打开“视频知识 → ASR 设置”，确认 yt-dlp、streamget、faster-whisper、FFmpeg、ffprobe 均显示可用。
6. 选择 `small` 模型并下载；CPU 推荐 `small + int8`，NVIDIA GPU 可使用 `float16`。
7. 在“添加内容”中选择来源：可以粘贴视频 URL，也可以切换到“本地视频”，填写或选择视频文件，
   再输入标题（必填）和作者（可选）。faster-whisper 配置下方可为当前内容选择 Hermes 知识分析模型；
   默认继承 Hermes 全局模型，任务级选择不会修改全局设置。提交后等待采集、Transcript 和知识结果完成。

本地视频支持常见的 MP4、MKV、MOV、AVI、WebM 等格式。识别时应用会把视频复制到受管媒体库，
不会移动或删除原文件；在复制完成前请勿移动、改名或删除该文件。

首次模型或 CUDA runtime 下载可能超过 15 分钟；15 分钟验收基线使用已有字幕的视频或 CPU small
模型，并要求网络可访问 GitHub、Python 包源和视频平台。

## 飞书视频知识闭环

管理员需要先配置 Feishu/Lark 应用、消息事件和 `FEISHU_ALLOWED_USERS`，保持
`FEISHU_ALLOW_ALL_USERS=false`，再设置 `VKC_MESSAGING_INGEST_ENABLED=true` 并重启 Hermes。私聊可直接发送：

```text
采集并分析这个视频：https://www.bilibili.com/video/BV...
```

群聊必须由白名单用户 @机器人；群话题内发送时，受理和终态结果都会回复原话题。受理回复包含 workflow ID，
长任务无需保持飞书窗口打开。可以继续发送“刚才的视频处理到哪里了”“取消刚才的视频任务”或
“重试刚才的视频任务”。当前接受 B 站、抖音和小红书普通点播视频，以及 b23.tv、v.douyin.com、xhslink.cn
官方短链；默认最长 30 分钟、最高 720p。平台触发登录或风控时，请先在 VKC 系统设置中选择对应平台的
Netscape Cookies 文件。
认证失败后再配置或更换 Cookies 文件也可以直接重试；系统会在重新排队前刷新该任务的平台 Cookies 配置。
系统设置中的“飞书采集限额”可启用或关闭配额检查，并分别配置每用户/每会话的活跃任务数与每日提交数；
保存后下一次飞书提交立即使用新配置，无需重启 Hermes。

## 升级与数据保留

直接运行新版安装包或使用 Hermes 更新入口。代码和 Desktop 会更新，以下用户数据保留：

- Session 与定时任务
- VKC 数据库、媒体、Transcript 和知识结果
- faster-whisper 模型缓存
- provider 配置与 profile

卸载时选择“仅 GUI”或“保留用户数据”可在重装后恢复；只有 full uninstall 会删除用户数据。
执行 full 前应备份 `%LOCALAPPDATA%\hermes`。

## 验证安装来源

RC 目录中的 `install-stamp.json` 应包含：

```json
{
  "schemaVersion": 2,
  "repository": "yknife/hermes-agent",
  "branch": "vkc-integration"
}
```

提交号必须与 `release-manifest.json` 的 `source.hermes_commit` 一致。
