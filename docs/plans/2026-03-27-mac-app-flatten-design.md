# mac-app Flatten Design

## Goal

删除失效的 `mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj` 空壳，
并把 `mac-app/HYMTQuickTranslate/` 下仍在使用的工程、源码、测试和品牌资源
扁平化到 `mac-app/` 根目录。

## Current State

- 当前真实工程是 `mac-app/HYMTQuickTranslate/Glint.xcodeproj`
- 当前真实源码目录是 `mac-app/HYMTQuickTranslate/Glint`
- 当前真实测试目录是 `mac-app/HYMTQuickTranslate/GlintTests`
- 当前真实品牌资源目录是 `mac-app/HYMTQuickTranslate/Branding`
- `mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj` 不包含
  `project.pbxproj`，只剩用户态 workspace 状态文件，已经不是可用工程

这说明 `HYMTQuickTranslate` 这一层现在只是在承载历史路径，不再代表有效的
产品结构。

## Options

### Option A: 只删除空壳工程

保留 `mac-app/HYMTQuickTranslate/` 这一层，删除失效的
`HYMTQuickTranslate.xcodeproj`。

优点：

- 改动最小
- 风险最低

缺点：

- 目录结构仍保留旧产品名
- 未来文档和脚本仍要继续解释这层历史包袱

### Option B: 直接扁平化到 `mac-app/`

把以下路径整体迁移：

- `mac-app/HYMTQuickTranslate/Glint.xcodeproj` -> `mac-app/Glint.xcodeproj`
- `mac-app/HYMTQuickTranslate/Glint` -> `mac-app/Glint`
- `mac-app/HYMTQuickTranslate/GlintTests` -> `mac-app/GlintTests`
- `mac-app/HYMTQuickTranslate/Branding` -> `mac-app/Branding`

然后删除空壳 `HYMTQuickTranslate.xcodeproj` 和空目录
`mac-app/HYMTQuickTranslate/`。

优点：

- 仓库结构与产品名 `Glint` 对齐
- README、脚本、工程路径都更短更直观
- 后续继续演进时不必再带着旧命名

缺点：

- 需要同步更新 Xcode 工程中的组路径、脚本和文档引用

### Option C: 重新命名为新的中间层目录

例如改成 `mac-app/GlintApp/`，继续保留一层容器目录。

优点：

- 比直接扁平化更保守

缺点：

- 没有解决“多一层无意义目录”的问题
- 只是把旧包袱换成新的包袱

## Decision

采用 **Option B**。

这次重构本质是路径整理，不是功能改造。只要把引用同步完整，收益明显高于
风险。

## Scope

### In Scope

- 删除空壳 `mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj`
- 扁平化 `mac-app/HYMTQuickTranslate/` 下仍在使用的目录
- 更新 `README.md`、`README.en.md`
- 更新 `scripts/build_mac_app.sh`
- 更新保留中的 `docs/plans` 路径引用
- 验证 `xcodebuild test` 和 `scripts/build_mac_app.sh`

### Out of Scope

- 修改 App 功能或交互
- 改产品名
- 重写测试逻辑
- 调整 `.runtime`、`dist` 等构建输出结构

## Implementation Notes

- 优先使用 `mv` 进行目录迁移，避免无意义内容重写
- Xcode 工程路径需要跟随迁移后的相对位置更新
- 仍保留 `Glint.xcodeproj` 这一工程名，不在这次顺带改成别的名字
- 仅删除已经确认失效的空壳工程和空目录，不碰其他无关目录

## Verification

- `xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`
- `zsh scripts/build_mac_app.sh`
- `rg -n "mac-app/HYMTQuickTranslate/Glint.xcodeproj|mac-app/HYMTQuickTranslate/Glint|mac-app/HYMTQuickTranslate/GlintTests|mac-app/HYMTQuickTranslate/Branding" README.md README.en.md scripts docs mac-app`
