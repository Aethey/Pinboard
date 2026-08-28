# Pinboard

**A spatial note board for macOS.**<br>
**一款自由、直观的 macOS 空间便签应用。**

![Pinboard preview](Image/image1.png)

[English](#english) · [中文](#中文)

---

<a id="english"></a>

## English

Pinboard turns your screen into a flexible space for thoughts, references, and temporary information. Place notes wherever they make sense, keep related ideas together, and leave important content visible while you work.

There are no folders to organize before you begin. Open a board, put something down, and shape the space as your ideas develop.

### Highlights

- **Write anywhere:** double-click an empty point to create a note exactly where you need it. Pinboard automatically adjusts placement near window edges.
- **Text, Markdown, and images:** keep quick thoughts, structured documents, screenshots, and visual references together on one canvas.
- **Multiple boards:** separate work, study, projects, and temporary material into independent spaces. Create or switch boards from the top control, and double-click a board name to rename it.
- **Fast search:** click Search or press `⌘F` to search the current board. Live suggestions appear as you type, unrelated cards fade into the background, and your 10 most recent searches remain close at hand.
- **Flexible cards:** move, resize, recolor, collapse, duplicate, lock, or delete a card. Clicking a card always brings it to the front.
- **Focused controls:** card actions stay compact and close to the content. Image controls appear only when you hover over that image.
- **Readable Markdown:** switch between source and preview, with support for headings, lists, code, links, and scrollable tables.
- **Board and Desktop modes:** press `⌥ Space` to keep notes floating over the desktop without blocking the apps underneath.
- **Grid snapping:** use the grid when you want a tidy layout, or turn it off for free placement.
- **Automatic saving:** your boards and notes remain available the next time you open Pinboard.
- **AI-ready:** Codex, Claude Code, and other MCP-compatible agents can create notes directly in Pinboard.

### Quick guide

| Action | How |
| --- | --- |
| Create a text note | Double-click the board or use the Text button |
| Create a Markdown note | Use the Markdown button |
| Add an image | Use the Image button and choose an image |
| Move a note | Drag anywhere on its title bar |
| Move an image | Hover over it, then drag the top-left handle |
| Resize a card | Drag the handle at the bottom-right |
| Edit a title | Double-click the title text |
| Change color or font size | Use the palette or font-size button |
| Collapse or expand | Use the chevron button |
| Duplicate a card | Right-click the card |
| Lock or delete | Use the title-bar controls |
| Create, switch, or rename a board | Use the board control; double-click its name to rename it |
| Search notes | Click Search or press `⌘F`; press Return to open the first result |
| Switch Board/Desktop mode | Press `⌥ Space` |
| Maximize or restore the window | Double-click the top edge of the window |

## MCP integration

MCP lets an AI agent create a text or Markdown note in Pinboard for you. For example, you can ask an agent to collect a response, save a plan, or place a reminder on your current board.

### 1. Find the Pinboard MCP helper

When Pinboard is installed in Applications, the helper is located at:

```text
/Applications/Pinboard.app/Contents/MacOS/pinboard-mcp
```

If Pinboard is installed somewhere else, use the same path inside that `Pinboard.app`. Use the absolute path in your agent configuration.

### 2. Connect Codex

```bash
codex mcp add pinboard -- /Applications/Pinboard.app/Contents/MacOS/pinboard-mcp
codex mcp list
```

Restart Codex after adding the server. In the desktop app, you can also open **Settings → MCP servers**, add a **STDIO** server, and use the helper path as its command.

### 3. Connect Claude Code

```bash
claude mcp add --transport stdio pinboard -- /Applications/Pinboard.app/Contents/MacOS/pinboard-mcp
claude mcp list
```

You can also enter `/mcp` in Claude Code to check the connection.

### 4. Connect another MCP-compatible agent

Many local agents accept a configuration like this:

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

The exact settings location depends on the agent.

### 5. Create a note with AI

Ask your agent something like:

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

Images are currently added from inside Pinboard rather than through MCP.

### MCP troubleshooting

- If the agent cannot find `create_note`, confirm that `pinboard` appears in its MCP list, then restart the agent or begin a new task.
- If Pinboard cannot be opened, confirm that the command points to the helper inside the installed `Pinboard.app`.
- If you keep more than one copy of Pinboard, point the command to the exact copy you want the agent to use.

---

<a id="中文"></a>

## 中文

Pinboard 把屏幕变成一块可以自由摆放的思考空间。临时想法、资料片段、待办、截图和需要持续关注的信息，都可以放到最合适的位置，并在工作过程中一直保持可见。

你不需要先创建复杂的目录，也不必在层层页面之间切换。打开画板、放下一张便签，然后让空间随着想法自然生长。

### 核心功能

- **随处创建：** 双击画板任意空白位置即可创建便签。靠近窗口边缘时，Pinboard 会自动选择放得下的方向。
- **文本、Markdown 与图片：** 快速记录、结构化内容、截图和视觉资料可以同时存在于一张画板上。
- **多个 Board：** 工作、学习、项目和临时资料可以放在不同画板中。通过顶部控件创建或切换 Board，双击名称即可改名。
- **快速搜索：** 点击搜索按钮或按 `⌘F` 检索当前 Board。输入时会实时联想，不相关的便签会自动淡化，并保留最近 10 条搜索记录。
- **自由调整便签：** 可以移动、缩放、换色、折叠、复制、锁定或删除；点击任何便签都会把它带到最上层。
- **紧凑的操作区：** 常用操作集中在标题栏，不打扰正文。图片的操作按钮只会在鼠标移入当前图片时出现。
- **清晰的 Markdown 预览：** 可以随时切换源码和预览，支持标题、列表、代码、链接以及可滚动表格。
- **Board / Desktop 模式：** 按 `⌥ Space` 切换。Desktop 模式可以让便签悬浮显示，同时不阻挡下面的应用。
- **网格吸附：** 需要整齐排列时打开网格，需要自由摆放时随时关闭。
- **自动保存：** 关闭后再次打开，Board 和便签仍会保留。
- **支持 AI：** Codex、Claude Code 和其他支持 MCP 的 Agent 可以直接在 Pinboard 中创建便签。

### 常用操作

| 想做什么 | 操作方式 |
| --- | --- |
| 创建文本便签 | 双击画板，或点击 Text 按钮 |
| 创建 Markdown 便签 | 点击 Markdown 按钮 |
| 添加图片 | 点击 Image 按钮并选择图片 |
| 移动文本便签 | 按住标题栏任意位置拖动 |
| 移动图片 | 鼠标移入图片后，拖动左上角把手 |
| 缩放便签 | 拖动右下角把手 |
| 编辑标题 | 双击标题文字 |
| 修改颜色或字体大小 | 点击调色板或字号按钮 |
| 折叠或展开 | 点击箭头按钮 |
| 复制便签 | 右键点击便签 |
| 锁定或删除 | 使用标题栏中的对应按钮 |
| 创建、切换或重命名 Board | 使用 Board 控件；双击名称可以重命名 |
| 搜索便签 | 点击搜索按钮或按 `⌘F`；按 Return 打开第一条结果 |
| 切换 Board / Desktop | 按 `⌥ Space` |
| 最大化或恢复窗口 | 双击窗口上边缘 |

## MCP 集成

MCP 可以让 AI Agent 直接帮你在 Pinboard 中创建文本或 Markdown 便签。例如，把一段回答保存到画板、生成一份计划，或者放下一张持续可见的提醒。

### 第一步：找到 Pinboard 的 MCP 辅助程序

把 Pinboard 安装到“应用程序”目录后，辅助程序位于：

```text
/Applications/Pinboard.app/Contents/MacOS/pinboard-mcp
```

如果 Pinboard 位于其他位置，请使用那个 `Pinboard.app` 内的相同路径。Agent 配置中需要填写绝对路径。

### 第二步：接入 Codex

```bash
codex mcp add pinboard -- /Applications/Pinboard.app/Contents/MacOS/pinboard-mcp
codex mcp list
```

添加后请重启 Codex。在桌面端中，也可以打开 **Settings → MCP servers**，添加一个 **STDIO** server，并把辅助程序路径填入 command。

### 第三步：接入 Claude Code

```bash
claude mcp add --transport stdio pinboard -- /Applications/Pinboard.app/Contents/MacOS/pinboard-mcp
claude mcp list
```

在 Claude Code 中输入 `/mcp`，也可以查看连接状态。

### 第四步：接入其他支持 MCP 的 Agent

许多本地 Agent 可以使用类似下面的配置：

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

具体设置位置取决于不同的 Agent。

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
| `x`, `y` | 否 | 便签中心位置；两个参数需要一起提供 |
| `theme` | 否 | `graphite`、`indigo`、`teal`、`amber` 或 `rose` |

目前图片仍然从 Pinboard 内导入，暂不通过 MCP 传入。

### MCP 常见问题

- Agent 找不到 `create_note`：确认 MCP 列表中已经出现 `pinboard`，然后重启 Agent 或新建一个任务。
- Pinboard 无法打开：确认 command 指向已安装 `Pinboard.app` 内部的辅助程序。
- 电脑中有多个 Pinboard：把 command 指向你希望 Agent 使用的那个应用副本。
