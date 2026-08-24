# ADR 0002：Windows RC 复用 Hermes Desktop 打包链路

## 状态

Accepted — 2026-08-24

## 背景

原始 Sprint 10 计划在 VKC 仍是独立 FastAPI/React 产品时提出“React 静态资源 + PyInstaller
onedir + Inno/WiX”。Sprint 6 之后，VKC 已迁入 Hermes Desktop、Gateway 和受监管 Worker，独立
VKC 可执行文件与监听端口均被移除。

## 决策

- 使用 Hermes Electron Builder 生成可更改安装目录的 per-user NSIS，以及可选 MSI。
- React/VKC 静态资源随 Desktop `app.asar` 交付。
- Python 代码通过 Hermes 管理的 checkout + venv 安装，保持 Gateway、profile、更新器和 Supervisor
  的单一所有权，不创建第二套 PyInstaller runtime。
- RC 安装签章记录 `repository + branch + commit`，首次安装从 `yknife/hermes-agent` 获取完全相同的
  VKC 提交；仓库 slug 必须通过严格校验。
- 默认卸载保留 `%LOCALAPPDATA%\hermes` 用户数据；只有明确选择 full 才删除。
- 每个制品生成 SHA-256 和机器可读 release manifest。

## 后果

优点是安装、升级、卸载和 Supervisor 与 Hermes 上游保持一致，且不引入第二个 API/Worker。
代价是首次安装需要访问 GitHub、uv/Python 依赖源，离线安装包不在本 RC 范围内。
