# System Translation Provider Design

## Goal

在 `API Settings` 中新增翻译提供方分页，让用户可以在
`Custom API` 和 `System Translation` 之间切换。
选择 `System Translation` 后，不再要求填写 `Base URL`、`API Key`、
`Model`，并且菜单翻译入口不再因为 HTTP 后端不可用而被禁用。

## Current State

- 当前 `API Settings` 只支持一套 `OpenAI-compatible` 风格配置
- `APISettings` 只保存 `baseURLString`、`apiKey`、`model`
- 默认翻译客户端 `LocalTranslationClient` 只会请求
  `/v1/chat/completions`
- 菜单栏状态完全由 `BackendStatusMonitor` 的 HTTP 探测结果控制
- 菜单翻译入口是否可用，直接依赖 `BackendStatusSnapshot.canTranslate`

这意味着现在的 App 把“翻译能力”与“HTTP API 可达性”绑死了。

## Options

### Option A: 在现有页面里加一个开关

在同一页里新增 `Use System Translation` 开关，并按开关隐藏字段。

优点：

- 改动面小

缺点：

- 交互语义弱，不符合“分一个页”的要求
- 会把两套完全不同的配置方式混在一页里

### Option B: 把 `API Settings` 拆成两个页签

页签：

- `Custom API`
- `System Translation`

`Custom API` 页保留现有 HTTP 配置，
`System Translation` 页只展示系统翻译说明，不展示 HTTP 字段。

优点：

- 与用户要求一致
- 配置边界清晰
- 后续如果再加别的 provider，也容易扩展

缺点：

- 需要把设置状态、后端状态、翻译客户端一起做 provider 化

### Option C: 直接废弃 HTTP 配置，只保留系统翻译

优点：

- 逻辑最简单

缺点：

- 会移除现有能力，不符合当前产品形态

## Decision

采用 **Option B**。

这次本质是把“翻译提供方”提升为一等配置：

- 设置页按 provider 分页
- 运行时翻译客户端按 provider 路由
- 菜单栏状态按 provider 生成，而不是一律做 HTTP 健康检查

## Scope

### In Scope

- 为 `APISettings` 新增 provider 持久化字段
- 将设置页改为 `Custom API` / `System Translation` 双页签
- 让默认翻译客户端根据 provider 路由到 HTTP 或系统翻译
- 让菜单状态在系统翻译模式下保持可翻译，并关闭“刷新状态”
- 补充对应单元测试

### Out of Scope

- 变更 OCR、划词、剪贴板的业务流程
- 调整快捷键面板
- 变更现有 HTTP API 协议
- 扩展更多翻译 provider

## Architecture

### 1. 配置层

新增 `TranslationProvider` 枚举：

- `customAPI`
- `system`

`APISettings` 保存 provider，并对旧数据做兼容解码：
如果历史持久化里没有 provider，默认回落到 `customAPI`。

### 2. UI 层

`APISettingsPanelViewState` 新增 provider 草稿字段。
设置面板顶部增加分段页签：

- `Custom API`：显示 `Base URL`、`API Key`、`Model`
- `System Translation`：显示系统翻译说明文案

模型刷新按钮仅在 `Custom API` 页可见且可用。

### 3. 运行时翻译层

保留现有 HTTP 客户端能力，但新增一个运行时路由客户端：

- `customAPI` -> 走当前 chat completion HTTP 请求
- `system` -> 走 macOS `Translation` framework

系统翻译实现通过一个 SwiftUI `translationTask` host 获取
`TranslationSession`，再把翻译结果回传给工作流。

### 4. 菜单状态层

新增一个“系统翻译模式”状态快照：

- headline 显示系统翻译模式
- detail 显示正在使用系统翻译
- `canTranslate == true`
- `canRefreshStatus == false`

`BackendStatusMonitor` 先读取当前 provider：

- `customAPI` 时继续做 HTTP 探测
- `system` 时直接返回系统翻译状态

## Error Handling

- 若系统版本低于 `macOS 15` 或系统翻译会话不可用，
  翻译动作返回用户可理解的错误提示
- 若 `customAPI` 缺少配置，保留现有错误语义
- 若用户从 `customAPI` 切到 `system`，保留原 HTTP 配置内容但不再要求填写

## Testing

- `APISettingsStoreTests`：
  provider round-trip、旧配置兼容解码
- `APISettingsPanelControllerTests`：
  provider 草稿保存、系统页不触发模型发现
- `BackendStatusMonitorTests`：
  系统 provider 不触发 HTTP 健康检查
- `MenuBarViewModelTests`：
  系统翻译状态下菜单可翻译、不可刷新
- `RuntimeTranslationClientTests`：
  provider 路由正确

## Verification

- `xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`
