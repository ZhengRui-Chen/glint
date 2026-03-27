# DMG Release Packaging Design

## Goal

为 Glint 增加一个最小可维护的 `.dmg` 打包链路，用于普通 macOS 发布分发，
不包含签名、notarization 或自定义 DMG 视觉美化。

## Current State

- 当前仓库只提供 `scripts/build_mac_app.sh`
- 当前构建产物是 `dist/Glint.app`
- 仓库内没有 `.dmg`、`hdiutil`、`codesign`、`notarytool` 或
  第三方打包工具相关流程

这意味着现在已经能产出可运行的 `.app`，但还缺少一个更适合发布分发的容器。

## Options

### Option A: 新增独立 `build_dmg.sh`

新增 `scripts/build_dmg.sh`，先构建 `.app`，再使用系统自带 `hdiutil`
生成 `dist/Glint.dmg`。

优点：

- 不引入第三方依赖
- `build_mac_app.sh` 与 `build_dmg.sh` 职责清晰
- 后续要补签名或 notarization 时更容易扩展

缺点：

- 比单脚本方案多一个入口

### Option B: 直接扩展 `build_mac_app.sh`

把 `.dmg` 生成逻辑直接并入现有脚本，一次输出 `.app` 和 `.dmg`。

优点：

- 入口更少

缺点：

- 本地开发只想构建 `.app` 时也会被迫经过发布步骤
- 脚本职责混在一起，后续扩展不清晰

### Option C: 引入第三方 DMG 工具

例如 `create-dmg` 之类的工具，顺带做窗口布局和背景图。

优点：

- 视觉效果更完整

缺点：

- 引入额外依赖
- 当前首个正式版没有必要增加复杂度

## Decision

采用 **Option A**。

当前目标是补齐一个稳定、低维护成本的发布打包步骤，而不是追求花哨的 DMG
展示效果。系统自带 `hdiutil` 足够完成这次需求。

## Scope

### In Scope

- 新增 `scripts/build_dmg.sh`
- 让 DMG 内包含 `Glint.app`
- 在 DMG 内额外放置 `Applications` 符号链接，支持拖拽安装
- 让 DMG 构建走 `Release` 配置
- 更新 `README.md` 和 `README.en.md` 的发布说明
- 增加一个最小 shell smoke test 验证 DMG 产物存在

### Out of Scope

- App 签名
- Apple notarization
- 自定义 DMG 背景、图标摆位、窗口大小
- GitHub Release 自动上传

## Implementation Notes

- `build_mac_app.sh` 需要支持可选 `CONFIGURATION`，默认仍保留 `Debug`
- `build_dmg.sh` 调用 `build_mac_app.sh` 时显式传入 `CONFIGURATION=Release`
- 使用临时 staging 目录生成 DMG，结束后清理临时目录
- 产物固定写入 `dist/Glint.dmg`

## Verification

- `zsh scripts/tests/build_dmg_smoke_test.sh`
- `zsh scripts/build_dmg.sh`
- `hdiutil imageinfo dist/Glint.dmg`
