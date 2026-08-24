# Windows RC 发布清单

## 自动门禁

- [ ] `scripts/check.ps1` 全部通过
- [ ] Hermes/VKC 工作树干净且提交已推送到 `yknife/hermes-agent:vkc-integration`
- [ ] `scripts/build-rc.ps1 -Target nsis` 成功
- [ ] `scripts/verify-rc.ps1` 校验 manifest、SHA-256、app.asar 和安装元数据
- [ ] `install-stamp.json` 指向 `yknife/hermes-agent` 的可获取提交

## Windows 矩阵

- [ ] 全新 Windows 10 x64 VM
- [ ] 全新 Windows 11 x64 VM
- [ ] 中文用户名
- [ ] 包含空格的用户名
- [ ] 非 C 盘安装目录
- [ ] 从上一 RC 覆盖升级，Session、cron、媒体、Transcript、知识结果和模型仍存在
- [ ] lite uninstall 后重装，用户数据恢复
- [ ] full uninstall 仅在明确确认后删除用户数据

## 15 分钟首视频闭环

- [ ] 首次启动完成 provider 配置
- [ ] 运行环境五项工具全部可用
- [ ] 添加含字幕的短视频
- [ ] 任务达到 SUCCEEDED
- [ ] 媒体可播放、Transcript 可跳转
- [ ] 摘要、章节、知识点、建议问答生成且引用可回跳

VM、中文用户名和升级/卸载属于发布前人工破坏性验证，不得在开发机的真实 `HERMES_HOME` 上执行。
