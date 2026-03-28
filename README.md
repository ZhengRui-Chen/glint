# Glint

<p align="center">
  <img src="docs/assets/glint-logo.png" alt="Glint logo" width="160" />
</p>

Glint 是一个面向 macOS 的菜单栏翻译客户端。

[中文](README.md) | [English](README.en.md)

<p align="center">
  <img src="docs/assets/glint-screenshot.png" alt="Glint screenshot" />
</p>

<p align="center">
  <img src="docs/assets/glint-ocr-demo.gif" alt="Glint OCR demo" />
</p>

<p align="center">
  <a href="docs/assets/glint-ocr-demo.mp4">查看 OCR 演示原视频</a>
</p>

## 项目定位

Glint 只负责 macOS 端交互：

- 菜单栏常驻
- 剪贴板翻译
- 选区翻译
- OCR 区域翻译
- 快捷键配置
- 翻译提供方配置

Glint ** 不再负责 ** 模型下载、服务启动、进程保活或本地部署脚本。

如果你需要我日常使用的后端部署仓库，请使用：

- `https://github.com/ZhengRui-Chen/HY-MT`

## 翻译提供方

Glint 现在支持两种翻译模式：

- `Custom API`
- `System Translation`

### Custom API

`Custom API` 适合连接你自己的兼容接口，当前会使用：

- `POST /v1/chat/completions`
- `GET /v1/models`

`/v1/models` 只用于拉取模型列表。
如果你的后端没有提供这个接口，仍然可以直接手动输入 `Model`。

### System Translation

`System Translation` 使用 macOS 自带的翻译能力，不需要配置：

- `Base URL`
- `API Key`
- `Model`

这个模式依赖系统翻译框架和对应语言支持。
如果当前语言方向不可用，设置页会直接显示状态。

## macOS App

### 运行

1. 打开 `mac-app/Glint.xcodeproj`
2. 运行 `Glint` scheme
3. 在菜单栏打开 `API Settings…`
4. 选择翻译模式：
   - `Custom API`：配置 `Base URL`、`API Key`、`Model`
   - `System Translation`：直接使用系统翻译

也可以直接构建：

```bash
zsh scripts/build_mac_app.sh
```

如果你要生成一个普通可分发的 DMG：

```bash
zsh scripts/build_dmg.sh
```

产物会写到 `dist/Glint.dmg`。

### API Settings

`API Settings…` 面板分成两个页签：

- `Custom API`
- `System Translation`

其中：

- `Custom API` 提供 `Base URL`、`API Key`、`Model`
- `Model` 支持手动输入
- `Model` 也支持从 `/v1/models` 刷新后下拉选择
- `System Translation` 会显示当前系统翻译可用性
- 配置保存在 `UserDefaults`

### 菜单栏能力

- 菜单顶部显示当前翻译提供方状态
- `Refresh Status` 用于主动刷新 `Custom API` 连通性
- `Translate Clipboard` 从剪贴板读取文本并展示翻译
- `Translate Selection` 读取当前选区并尽量在光标附近展示结果
- `Translate OCR Area` 允许框选屏幕区域做 OCR 后翻译
- `Keyboard Shortcuts…` 用于录制全局快捷键

### 默认快捷键

- Clipboard: `Control + Option + Command + T`
- Selection: `Control + Option + Command + S`
- OCR: `Control + Option + Command + O`

## 后端仓库

当前推荐把后端部署、模型管理和服务运维放在独立仓库中：

- `https://github.com/ZhengRui-Chen/HY-MT`

如果你使用 `Custom API`，可以先在那个仓库里准备好服务，再把连接信息填回 Glint。
