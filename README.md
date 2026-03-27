# Glint

<p align="center">
  <img src="docs/assets/glint-logo.png" alt="Glint logo" width="160" />
</p>

Glint 是一个面向 macOS 的本地翻译应用，依赖本地
OpenAI-compatible 翻译后端；当前仓库内置的默认实现是 `oMLX` + `HY-MT`。

[中文](README.md) | [English](README.en.md)

> 当前项目主要按个人使用场景维护，暂时没有提供可直接下载安装的 release 版本。
> 如果你希望使用 Glint，请根据本文自行完成本地编译、模型准备与服务部署。

<p align="center">
  <img src="docs/assets/glint-screenshot.png" alt="Glint screenshot" />
</p>

<p align="center">
  <img src="docs/assets/glint-ocr-demo.gif" alt="Glint OCR demo" />
</p>

<p align="center">
  <a href="docs/assets/glint-ocr-demo.mp4">查看 OCR 演示原视频</a>
</p>

## 项目简介

Glint 是一个菜单栏常驻的 macOS 翻译工具，提供剪贴板翻译、选区翻译、
快捷键配置以及本地后端状态管理。它面向的是需要自己控制模型、服务和
运行环境的本地工作流，而不是开箱即用的发布版。

当前默认栈里：

- `Glint` 负责 macOS 菜单栏交互和翻译入口
- `oMLX` 负责本地服务层
- `HY-MT1.5-1.8B-4bit` 是当前默认模型

## Quick Start

以下步骤使用的是 **本仓库当前唯一内置并验证过的后端实现**
`oMLX + HY-MT`：

```bash
uv sync
cp configs/omlx.env.example configs/omlx.env
mkdir -p models/HY-MT1.5-1.8B-4bit
zsh scripts/start_omlx_tmux.sh
zsh scripts/status_omlx.sh
open mac-app/HYMTQuickTranslate/Glint.xcodeproj
```

如果你想先验证命令行链路，可以运行：

```bash
uv run python scripts/repl_translate.py
```

如果你想直接构建 macOS app，可以运行：

```bash
zsh scripts/build_mac_app.sh
```

## macOS App

### 运行 Glint

1. 打开 `mac-app/HYMTQuickTranslate/Glint.xcodeproj`。
2. 确认本地 `oMLX` 服务已启动，并监听 `http://127.0.0.1:8001`。
3. 运行 `Glint` scheme。
4. 使用菜单栏图标触发翻译或配置快捷键。

### 菜单栏能力

- 菜单顶部会显示后端状态，便于判断翻译服务是否可用。
- `Start Service`、`Stop Service`、`Restart Service`、`Refresh Status`
  用于管理本地后端。
- `Translate Clipboard` 从剪贴板读取文本并打开翻译浮层。
- `Translate Selection` 读取当前选区并尽量在光标附近展示结果。
- 当后端不可用或正在启动时，翻译入口会自动禁用。
- `Selection Shortcut` 和 `Clipboard Shortcut` 可分别录制两个全局快捷键。

### 默认快捷键

- Clipboard: `Control + Option + Command + T`
- Selection: `Control + Option + Command + S`

### 选区与剪贴板

- 剪贴板翻译始终读取剪贴板内容，并以居中方式展示浮层。
- 选区翻译通过 macOS Accessibility API 读取当前文本选区。
- 选区路径会优先尝试在光标附近展示，失败后安全回退到居中展示。
- 选区路径不会回退到剪贴板内容；没有可用选区时会直接报错。

### 快捷键配置

- 剪贴板和选区快捷键分别配置。
- 录制期间若发生重复分配，会被拒绝。
- 更新后的快捷键会被持久化，并在下次启动时恢复。

## Backend Integration

Glint 当前不是直接绑定某个固定的后端仓库，而是依赖一个本地
OpenAI-compatible HTTP 服务。对 App 来说，真正重要的是接口契约是否匹配。

### App 当前默认值

下面这些值来自当前代码里的 `AppConfig.default`：

- Base URL: `http://127.0.0.1:8001`
- Model: `HY-MT1.5-1.8B-4bit`
- API Key: `local-hy-key`

注意：这些值目前是 **写死在 App 代码里** 的，不是从 `configs/omlx.env`
动态读取。也就是说，如果你的自定义后端不使用这些默认值，你还需要同步修改
macOS App 里的 `AppConfig.swift`。

### 后端最小契约

#### 1. 健康检查

App 会用下面这个请求判断后端是否可用：

```http
GET /v1/models
Authorization: Bearer <apiKey>
```

当前实现里只检查是否返回 `2xx`，不会消费特定的响应体结构。

#### 2. 翻译请求

App 会向下面这个接口发送翻译请求：

```http
POST /v1/chat/completions
Authorization: Bearer <apiKey>
Content-Type: application/json
```

最小请求体示例：

```json
{
  "model": "HY-MT1.5-1.8B-4bit",
  "messages": [
    {
      "role": "user",
      "content": "将以下文本翻译为中文，注意只需要输出翻译后的结果，不要额外解释：\n\nIt is a pleasure to meet you."
    }
  ],
  "max_tokens": 256,
  "temperature": 0.2
}
```

App 当前只会从下面这个最小响应结构里取值：

```json
{
  "choices": [
    {
      "message": {
        "content": "很高兴见到你。"
      }
    }
  ]
}
```

也就是说，你的后端至少要保证：

- 支持 `Bearer` 鉴权头
- `GET /v1/models` 返回 `2xx`
- `POST /v1/chat/completions` 接受 `model`、`messages`、`max_tokens`、
  `temperature`
- 响应里包含 `choices[0].message.content`

### 提示词约束

Glint 当前会直接把用户输入包装成如下翻译提示词：

```text
将以下文本翻译为{target_language}，注意只需要输出翻译后的结果，不要额外解释：

{source_text}
```

因此，一个兼容后端至少需要能稳定处理这种单轮中文指令式翻译请求，并返回
**纯翻译结果**，不要额外解释。

## Default Backend In This Repo

本仓库当前只提供并验证了 `oMLX + HY-MT` 这一套默认实现。也就是说：

- 提供了 `configs/omlx.env` 配置入口
- 提供了 `scripts/start_omlx*.sh`、`stop_omlx.sh`、`restart_omlx.sh`
- 提供了 `scripts/status_omlx.sh` 用于进程和 API 状态检查
- 提供了 `scripts/api_smoke.py`、`scripts/smoke_cli.py`、
  `scripts/smoke_suite.py` 用于验证

仓库 **没有** 提供：

- 其他后端的启动脚本
- 其他后端的配置模板
- 多后端切换机制
- 运行时可配置的 `baseURL` / `model` / `apiKey`

如果你只是想直接跑通项目，继续使用下面这套 `oMLX` 默认路径即可。

### oMLX 默认实现配置

Glint 默认依赖本地 `oMLX` 服务提供翻译能力。服务配置位于
`configs/omlx.env`，可直接从示例文件复制：

```bash
cp configs/omlx.env.example configs/omlx.env
```

启动服务：

```bash
zsh scripts/start_omlx.sh
```

停止服务：

```bash
zsh scripts/stop_omlx.sh
```

检查状态：

```bash
zsh scripts/status_omlx.sh
```

如果你使用 macOS LaunchAgent：

```bash
zsh scripts/install_omlx_launch_agent.sh
zsh scripts/start_omlx_launch_agent.sh
zsh scripts/status_omlx_launch_agent.sh
```

对应的停止、重启和卸载脚本也都在 `scripts/` 下。

## Bring Your Own Backend

如果你想把 Glint 接到别的本地后端，而不是当前仓库内置的 `oMLX`，建议按下面
这个 checklist 逐项确认：

- 后端监听地址与 App 当前默认值一致，或者你已经修改了 `AppConfig.swift`
- 后端接受 `Authorization: Bearer <apiKey>`
- `GET /v1/models` 能稳定返回 `2xx`
- `POST /v1/chat/completions` 接受当前请求字段
- 返回体包含 `choices[0].message.content`
- 模型能理解当前中文翻译提示词，并只输出翻译结果

如果你的后端满足这些条件，Glint 理论上就可以复用同一套 App 交互层。
但请注意：**本仓库只对 `oMLX + HY-MT` 这条路径做了脚本化支持和现成验证。**

### 验证命令

CLI smoke test：

```bash
uv run python scripts/smoke_cli.py \
  --model-id ./models/HY-MT1.5-1.8B-4bit \
  --text "It is a pleasure to meet you." \
  --target-language 中文 \
  --max-tokens 64
```

Expected output：

```text
很高兴能见到您。
```

Full smoke suite：

```bash
uv run python scripts/smoke_suite.py
```

OpenAI-compatible API smoke test：

```bash
python3 scripts/api_smoke.py
```

## Model And Prompt

推荐使用的本地模型目录：

- `models/HY-MT1.5-1.8B-4bit`

下载来源：

- `mlx-community/HY-MT1.5-1.8B-4bit`
- `tencent/HY-MT1.5-1.8B`

至少把以下文件放到 `models/HY-MT1.5-1.8B-4bit/`：

- `model.safetensors`
- `config.json`
- `tokenizer.json`
- `tokenizer_config.json`
- `special_tokens_map.json`

当前仓库默认实现遵循官方 HY-MT 的翻译提示词格式：

```text
将以下文本翻译为{target_language}，注意只需要输出翻译后的结果，不要额外解释：

{source_text}
```

推荐的推理参数：

- `top_k: 20`
- `top_p: 0.6`
- `repetition_penalty: 1.05`
- `temperature: 0.7`

## Project Layout

- CLI environment: `.venv`
- oMLX environment: `.venv-omlx`
- Model path: `models/HY-MT1.5-1.8B-4bit`
- Local service overrides: `configs/omlx.env`
- Glint app: `mac-app/HYMTQuickTranslate/Glint.xcodeproj`

## Upstream

- oMLX repository: https://github.com/jundot/omlx
- Tencent Hunyuan HY-MT: https://github.com/Tencent-Hunyuan/HY-MT
- MLX community model: https://huggingface.co/mlx-community/HY-MT1.5-1.8B-4bit
