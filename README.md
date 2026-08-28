# Pinboard

**A local-first spatial note board for macOS.**<br>
**一款本地优先的 macOS 空间便签应用。**

[English](#english) · [中文](#中文)

---

<a id="english"></a>

## English

Pinboard gives text, Markdown, and images a permanent place on a free-form canvas. Arrange ideas visually, keep the board floating over your desktop when needed, or let an AI agent add notes through MCP.

### Features

- **Three card types:** plain text, rendered Markdown, and images.
- **Create where you think:** double-click an empty place to create a text note there. Near an edge, Pinboard automatically places the card on the side where it fits.
- **A spatial canvas:** drag, resize, duplicate, lock, or delete cards. The card you click moves to the front.
- **Dense title-bar controls:** change color, cycle through three font sizes, collapse, delete, or lock a note directly from its title bar. The largest font is twice the size of the smallest.
- **Collapsible notes:** collapse a text or Markdown note to its title bar and expand it again whenever you need the content.
- **Better images:** Pinboard reads an image's dimensions before adding it and keeps its original aspect ratio while resizing. Image controls appear only while that image is hovered.
- **Markdown preview:** switch between Markdown source and rendered content inside the card.
- **Board and Desktop modes:** press `⌥ Space` to switch modes. Desktop mode is floating and click-through, so notes stay visible without blocking other apps.
- **Grid snapping:** turn snapping on or off from the top toolbar.
- **Native window behavior:** double-click the top edge of the window to maximize or restore it.
- **Local persistence:** cards are saved automatically on this Mac with SwiftData.
- **AI integration:** a bundled local MCP server lets Codex, Claude Code, and other compatible agents create notes.

### Requirements

- A Mac running macOS 26.5 or later, according to the current app target.
- Xcode 26.x is recommended for building the app.
- Xcode resolves the pinned Swift package dependencies automatically.

### Build and run

1. Open `Pinboard.xcodeproj` in Xcode.
2. Select the `Pinboard` scheme and your Mac as the destination.
3. Press **Run**.

Xcode builds both the app and its MCP helper. The finished app contains:

```text
Pinboard.app/Contents/MacOS/pinboard-mcp
```

The helper is also included automatically when you Archive or export the app. Users do not need the source repository or a separate `swift build`.

### Quick guide

| What you want to do | How |
| --- | --- |
| Create a text note | Double-click the board, or use the Text button |
| Create Markdown | Use the Markdown button |
| Add an image | Use the Image button and choose a local image |
| Move a note | Press and drag anywhere on its title bar |
| Move an image | Hover the image, then drag the handle at the top-left |
| Resize a card | Drag the handle at the bottom-right |
| Edit a note title | Double-click the title text |
| Change color or font size | Use the palette or font-size button in the title bar |
| Collapse or expand a note | Use the chevron button in the title bar |
| Lock or delete | Use the title-bar buttons; right-click to duplicate |
| Bring a card to the front | Click or edit that card |
| Switch Board/Desktop mode | Press `⌥ Space` |
| Maximize the window | Double-click the top edge of the window |

## MCP integration

### What is MCP here?

MCP lets an AI agent call a small Pinboard tool. In plain language:

`AI agent → local pinboard-mcp helper → Pinboard app → local SwiftData storage`

The helper uses STDIO, runs only on your Mac, and does not open a network port.

### 1. Find the bundled MCP helper

After installing Pinboard in Applications, the helper is at:

```text
/Applications/Pinboard.app/Contents/MacOS/pinboard-mcp
```

If the app is somewhere else, use the same path inside that `.app`. Always use an absolute path in agent configuration.

### 2. Connect Codex

Run:

```bash
codex mcp add pinboard -- /Applications/Pinboard.app/Contents/MacOS/pinboard-mcp
codex mcp list
```

The ChatGPT desktop app, Codex CLI, and Codex IDE extension share MCP configuration on the same host. Restart the client after adding the server. In the desktop app, you can also open **Settings → MCP servers**, add a **STDIO** server, and paste the executable path as its command.

### 3. Connect Claude Code

Run:

```bash
claude mcp add --transport stdio pinboard -- /Applications/Pinboard.app/Contents/MacOS/pinboard-mcp
claude mcp list
```

In Claude Code, `/mcp` also shows the current connection status.

### 4. Connect another MCP-compatible agent

Many local agents accept a JSON entry like this. The exact file name and location depend on the agent:

```json
{
  "mcpServers": {
    "pinboard": {
      "type": "stdio",
      "command": "/Applications/Pinboard.app/Contents/MacOS/pinboard-mcp",
      "args": []
    }
  }
}
```

### 5. Ask the agent to create a note

For example:

```text
Use Pinboard to create a Markdown note titled "Today" with three tasks.
```

The MCP tool is named `create_note`.

| Parameter | Required | Meaning |
| --- | --- | --- |
| `content` | Yes | Note body, up to 20,000 characters |
| `title` | No | Note title, up to 200 characters |
| `kind` | No | `text` (default) or `markdown` |
| `x`, `y` | No | Card center position; provide both together |
| `theme` | No | `graphite`, `indigo`, `teal`, `amber`, or `rose` |

Images are currently added from the app, not through MCP.

### If you have more than one Pinboard build

Point the MCP command at the helper inside the exact app you want. A bundled helper automatically finds its own enclosing `Pinboard.app`, so it will not depend on whichever development build macOS registered most recently.

The repository still contains `MCP/Package.swift` for standalone development. If you intentionally run `MCP/.build/release/pinboard-mcp` outside an app bundle, set `PINBOARD_APP_PATH=/absolute/path/to/Pinboard.app`.

### Troubleshooting

- **“Pinboard could not be opened”** — make sure the MCP command points to the helper inside a real `Pinboard.app`. Standalone development builds may need `PINBOARD_APP_PATH`.
- **The agent cannot see `create_note`** — confirm that `pinboard` appears in the client's MCP list, then restart the client or start a new task.
- **You changed code under `MCP/`** — rebuild the Pinboard app in Xcode, then restart the AI client so it starts the newly bundled helper.
- **A note appears in the wrong build** — change the MCP command to the helper inside the intended `.app`.

### Data and dependencies

- Notes and image data are stored locally through SwiftData.
- MCP requests are validated before they reach the app.
- The MCP helper uses the official [Model Context Protocol Swift SDK](https://github.com/modelcontextprotocol/swift-sdk), pinned to version `0.12.1` in both the Xcode project and `MCP/Package.swift`.

Official setup references: [Codex MCP documentation](https://learn.chatgpt.com/docs/extend/mcp) and [Claude Code MCP documentation](https://code.claude.com/docs/en/mcp).

---

<a id="中文"></a>

## 中文

Pinboard 把文本、Markdown 和图片放进一张可以自由排列的画布里。你可以像整理桌面便签一样摆放想法，也可以让便签悬浮在桌面上，或者通过 MCP 让 AI 帮你创建便签。

### 功能介绍

- **三种便签：** 普通文本、可渲染的 Markdown 和图片。
- **双击即创建：** 双击画布空白处，就会在该位置创建文本便签。如果靠近边缘，Pinboard 会自动换到放得下的一侧。
- **自由布局：** 便签可以移动、缩放、复制、锁定和删除。点击任何便签，它都会来到最上层。
- **高密度标题栏：** 可以直接修改颜色、循环切换三档字体、折叠、删除或锁定；最大字号是最小字号的两倍。
- **便签折叠：** 文本和 Markdown 便签可以只保留标题栏，需要时再展开内容。
- **图片保持比例：** 导入前会读取图片尺寸；创建和缩放时都会保持原图比例。只有鼠标移入当前图片时，才显示它的边框和操作按钮。
- **Markdown 预览：** 可以在 Markdown 源码和渲染结果之间切换。
- **Board / Desktop 模式：** 按 `⌥ Space` 切换。Desktop 模式会悬浮显示并穿透鼠标，不会挡住其他应用的操作。
- **网格吸附：** 可以在顶部工具栏中打开或关闭。
- **符合 macOS 习惯：** 双击窗口上边缘，可以最大化或恢复窗口。
- **本地持久化：** 便签通过 SwiftData 自动保存在这台 Mac 上。
- **AI 集成：** 项目内置本地 MCP server，Codex、Claude Code 和其他兼容 Agent 都可以调用它创建便签。

### 环境要求

- 按当前项目配置，应用需要 macOS 26.5 或更高版本。
- 推荐使用 Xcode 26.x 构建应用。
- Xcode 会自动解析项目中已经锁定版本的 Swift Package 依赖。

### 构建并运行

1. 用 Xcode 打开 `Pinboard.xcodeproj`。
2. 选择 `Pinboard` scheme，并把运行目标设为你的 Mac。
3. 点击 **Run**。

Xcode 会同时构建应用和 MCP 辅助程序。最终应用中会包含：

```text
Pinboard.app/Contents/MacOS/pinboard-mcp
```

执行 Archive 或导出应用时，这个辅助程序也会自动包含进去。最终用户不需要下载源码，也不需要另外执行 `swift build`。

### 常用操作

| 想做什么 | 操作方式 |
| --- | --- |
| 创建文本便签 | 双击画布，或点击 Text 按钮 |
| 创建 Markdown | 点击 Markdown 按钮 |
| 添加图片 | 点击 Image 按钮并选择本地图片 |
| 移动文本便签 | 按住标题栏任意位置拖动 |
| 移动图片 | 鼠标移入图片后，拖动左上角把手 |
| 缩放便签 | 拖动右下角把手 |
| 编辑标题 | 双击标题文字 |
| 修改颜色或字体大小 | 点击标题栏中的调色板或字号图标 |
| 折叠或展开 | 点击标题栏中的箭头按钮 |
| 锁定或删除 | 使用标题栏按钮；右键可以复制 |
| 把便签移到最上层 | 点击或编辑该便签 |
| 切换 Board / Desktop | 按 `⌥ Space` |
| 最大化窗口 | 双击窗口上边缘 |

## MCP 集成

### MCP 在这里是做什么的？

MCP 可以让 AI 调用 Pinboard 提供的小工具。简单来说，过程是：

`AI Agent → 本地 pinboard-mcp 辅助程序 → Pinboard 应用 → 本地 SwiftData 数据`

这个辅助程序使用 STDIO，只在本机运行，不会开放网络端口。

### 第一步：找到应用内置的 MCP 辅助程序

把 Pinboard 安装到“应用程序”目录后，辅助程序位于：

```text
/Applications/Pinboard.app/Contents/MacOS/pinboard-mcp
```

如果应用放在其他位置，就使用那个 `.app` 里面的相同路径。Agent 配置中一定要使用绝对路径。

### 第二步：接入 Codex

运行：

```bash
codex mcp add pinboard -- /Applications/Pinboard.app/Contents/MacOS/pinboard-mcp
codex mcp list
```

同一台电脑上的 ChatGPT 桌面端、Codex CLI 和 Codex IDE 扩展共用 MCP 配置。添加后请重启客户端。在桌面端里，也可以打开 **Settings → MCP servers**，添加一个 **STDIO** server，并把上面的可执行文件绝对路径填入 command。

### 第三步：接入 Claude Code

运行：

```bash
claude mcp add --transport stdio pinboard -- /Applications/Pinboard.app/Contents/MacOS/pinboard-mcp
claude mcp list
```

在 Claude Code 中输入 `/mcp`，也可以查看连接状态。

### 第四步：接入其他支持 MCP 的 Agent

许多本地 Agent 可以使用下面这种 JSON 配置。不同 Agent 的配置文件名称和位置可能不同：

```json
{
  "mcpServers": {
    "pinboard": {
      "type": "stdio",
      "command": "/Applications/Pinboard.app/Contents/MacOS/pinboard-mcp",
      "args": []
    }
  }
}
```

### 第五步：让 AI 创建便签

例如，对 Agent 说：

```text
使用 Pinboard 创建一个 Markdown 便签，标题是“今日计划”，内容是三条待办。
```

MCP 工具名是 `create_note`。

| 参数 | 必填 | 说明 |
| --- | --- | --- |
| `content` | 是 | 便签正文，最多 20,000 个字符 |
| `title` | 否 | 便签标题，最多 200 个字符 |
| `kind` | 否 | `text`（默认）或 `markdown` |
| `x`, `y` | 否 | 便签中心位置；两个参数必须一起提供 |
| `theme` | 否 | `graphite`、`indigo`、`teal`、`amber` 或 `rose` |

目前图片仍然从应用内导入，不通过 MCP 传入。

### 电脑里有多个 Pinboard 构建时

把 MCP command 指向你想使用的那个 `.app` 内部的 helper。内置 helper 会自动找到它所在的 `Pinboard.app`，不会依赖 macOS 最近注册的是哪个开发构建。

仓库仍然保留 `MCP/Package.swift`，方便单独开发。如果你特意运行应用外部的 `MCP/.build/release/pinboard-mcp`，才需要设置 `PINBOARD_APP_PATH=/完整路径/Pinboard.app`。

### 常见问题

- **提示“Pinboard could not be opened”**：确认 MCP command 指向一个真实 `Pinboard.app` 内部的 helper。只有单独构建的开发版本可能需要 `PINBOARD_APP_PATH`。
- **Agent 看不到 `create_note`**：先确认 MCP 列表里能看到 `pinboard`，然后重启客户端或新建一个任务。
- **修改了 `MCP/` 下的代码**：在 Xcode 中重新构建 Pinboard，再重启 AI 客户端，让它启动应用内最新的 helper。
- **便签出现在错误的开发构建里**：把 MCP command 改成目标 `.app` 内部的 helper 路径。

### 数据与依赖

- 便签和图片数据通过 SwiftData 保存在本机。
- MCP 请求会先经过校验，再交给应用处理。
- MCP 辅助程序使用官方 [Model Context Protocol Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)，并在 Xcode 工程和 `MCP/Package.swift` 中精确锁定为 `0.12.1`。

官方配置参考：[Codex MCP 文档](https://learn.chatgpt.com/docs/extend/mcp)和 [Claude Code MCP 文档](https://code.claude.com/docs/en/mcp)。
