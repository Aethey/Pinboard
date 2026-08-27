# Pinboard

Pinboard 是一个 macOS 空间便签应用。便签保存在本机 SwiftData 数据库中；文本、Markdown 和图片卡片可以自由移动、缩放并置于桌面层。

## 运行应用

用 Xcode 打开 `Pinboard.xcodeproj`，选择 `Pinboard` scheme 后运行。MCP 第一次使用前必须至少启动一次 Pinboard，让 macOS 注册 `pinboard://` URL scheme。

## MCP：让 AI 创建便签

仓库内的 `MCP` 目录提供本地 STDIO MCP server，工具名为 `create_note`。它只在本机运行，不开放网络端口；收到请求后，通过 `pinboard://create-note` 把经过校验的内容交给 Pinboard，再由应用统一写入 SwiftData。

当前使用 [Model Context Protocol 官方 Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) `0.12.1`，并在 `Package.swift` 中精确锁定版本。SDK 要求 Swift 6 / Xcode 16 或更高版本。

先构建 MCP server：

```bash
swift build --package-path MCP -c release
```

生成的可执行文件为：

```text
<仓库绝对路径>/MCP/.build/release/pinboard-mcp
```

配置里请始终使用绝对路径。相对路径会随 AI 客户端的启动目录变化。

### Codex

```bash
codex mcp add pinboard -- /绝对路径/Pinboard/MCP/.build/release/pinboard-mcp
codex mcp list
```

Codex 桌面端、CLI 和 IDE 在同一台主机上共用 MCP 配置。新开一个任务（或重启当前客户端）后，可以直接说：

```text
使用 Pinboard 的 create_note 创建一个 Markdown 便签，标题是「今日计划」，内容是三条待办。
```

如果开发机磁盘上同时存在多个 Pinboard `.app`，请先退出正在运行的旧版，再明确指定下一次要启动的构建：

```bash
codex mcp remove pinboard
codex mcp add \
  --env PINBOARD_APP_PATH=/完整路径/Pinboard.app \
  pinboard -- /绝对路径/Pinboard/MCP/.build/release/pinboard-mcp
```

### Claude Code

```bash
claude mcp add --transport stdio pinboard -- /绝对路径/Pinboard/MCP/.build/release/pinboard-mcp
claude mcp list
```

Claude Code 同样支持在 `pinboard` 名称之前添加 `--env PINBOARD_APP_PATH=/完整路径/Pinboard.app`。

若希望把配置提交给团队，可在项目根目录的 `.mcp.json` 使用通用 STDIO 格式：

```json
{
  "mcpServers": {
    "pinboard": {
      "type": "stdio",
      "command": "/绝对路径/Pinboard/MCP/.build/release/pinboard-mcp",
      "args": [],
      "env": {
        "PINBOARD_APP_PATH": "/完整路径/Pinboard.app"
      }
    }
  }
}
```

其他支持本地 STDIO MCP 的 Agent 也可使用同一段 `command` / `args` 配置。

## `create_note` 参数

| 参数 | 必填 | 说明 |
| --- | --- | --- |
| `content` | 是 | 便签正文，最多 20,000 个字符 |
| `title` | 否 | 标题，最多 200 个字符 |
| `kind` | 否 | `text`（默认）或 `markdown` |
| `x`, `y` | 否 | 便签中心在画布中的位置，必须同时提供；超出画布会自动收回可见区域 |
| `theme` | 否 | `graphite`、`indigo`、`teal`、`amber` 或 `rose` |

图片暂不通过 MCP 导入；图片依旧从应用工具栏选择，以避免把大体积二进制内容放进 STDIO 请求。

## 故障排查

- MCP 返回“Pinboard could not be opened”：先从 Xcode 启动一次应用，再重试。开发环境也可为 MCP server 设置 `PINBOARD_APP_PATH=/完整路径/Pinboard.app`。
- Agent 看不到 `create_note`：用客户端的 MCP 列表命令确认 `pinboard` 已连接，然后重启任务。
- 修改 MCP 源码后：重新执行 release 构建，再重启 AI 客户端，让它重启 STDIO 子进程。

参考：[Codex MCP 文档](https://learn.chatgpt.com/docs/extend/mcp)、[Claude Code MCP 文档](https://code.claude.com/docs/en/mcp)、[MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)。
