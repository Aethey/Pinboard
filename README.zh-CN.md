# Pinboard

[English](README.md) · **简体中文** · [日本語](README.ja.md)

**一款自由、直观的 macOS 空间便签应用。**

![Pinboard 预览](Image/image1.png)

## 下载

[**下载 Pinboard 1.0 for macOS（.dmg）**](https://github.com/Aethey/Pinboard/releases/latest/download/Pinboard-1.0.dmg)

打开 DMG，然后把 **Pinboard** 拖入“**应用程序**”文件夹。当前版本用于本地体验，暂未进行 Apple 公证。如果 macOS 首次启动时阻止打开，请在“应用程序”中按住 Control 点击 Pinboard，选择“**打开**”，然后再次确认。

Pinboard 把屏幕变成一块可以自由摆放的思考空间。临时想法、资料片段、待办、截图和需要持续关注的信息，都可以放到最合适的位置，并在工作过程中一直保持可见。

你不需要先创建复杂的目录，也不必在层层页面之间切换。打开画板、放下一张便签，然后让空间随着想法自然生长。

## 核心功能

- **随处创建：** 双击画板任意空白位置即可创建便签。靠近窗口边缘时，Pinboard 会自动选择放得下的方向。
- **无限画布：** 可以自由平移，并在 25% 到 250% 之间缩放。点击顶部控制栏的 100% 按钮或按 `⌘0`，即可恢复原始比例，同时保留当前画布中心。
- **便签、文件与链接：** 文本、Markdown、图片、PDF 和网页资料可以同时存在于一张画板上。
- **丰富的链接预览：** 粘贴或拖入 YouTube、TikTok、Bilibili、X、Vimeo 以及大多数公开网页的 URL 后，会自动获取标题、简介和预览图；如果网页没有元数据，则显示简洁的链接地址与添加时间。
- **调用系统应用查看：** 双击 PDF 会使用默认 PDF 应用打开，双击链接则使用默认浏览器打开。
- **多个 Board：** 工作、学习、项目和临时资料可以放在不同画板中。通过顶部控件创建或切换 Board，双击名称即可改名。
- **快速搜索：** 点击搜索按钮或按 `⌘F` 检索当前 Board。输入时会实时联想，不相关的便签会自动淡化，并保留最近 10 条搜索记录。
- **自由调整便签：** 可以移动、缩放、换色、折叠、复制、锁定或删除；点击任何便签都会把它带到最上层。
- **紧凑的操作区：** 常用操作集中在标题栏，不打扰正文。图片的操作按钮只会在鼠标移入当前图片时出现。
- **图片 OCR：** 识别本地图片中的文字，并以左侧图片、右侧可编辑文本的方式查看。
- **清晰的 Markdown 预览：** 可以随时切换源码和预览，支持标题、列表、代码、链接以及可滚动表格。
- **Board / Desktop 模式：** 按 `⌥ Space` 切换。Desktop 模式可以让便签悬浮显示，同时不阻挡下面的应用。
- **网格吸附：** 需要整齐排列时打开网格，需要自由摆放时随时关闭。
- **自动保存：** 关闭后再次打开，Board、便签和画布视角仍会保留。
- **不重复保存原文件：** 图片和 PDF 通常继续保留在 Finder 中的原位置，Pinboard 只记住访问权限并生成轻量预览；如果 macOS 无法保留访问权限，才会自动保存一份私有副本。大文件不会进入便签数据库。
- **AI 对话归档：** 只需让支持 MCP 的 Agent 保存当前对话，它会自动生成 Markdown 摘要、识别 ChatGPT、Claude、Gemini、Cursor 或 Codex，并在已有真实分享链接时一并保存。

## 常用操作

| 想做什么 | 操作方式 |
| --- | --- |
| 创建文本便签 | 双击画板，或点击 Text 按钮 |
| 创建 Markdown 便签 | 点击 Markdown 按钮 |
| 添加图片 | 点击 Image 按钮并选择图片 |
| 添加 PDF | 点击 PDF 按钮，或把 PDF 拖入、粘贴到画板 |
| 添加网页或视频链接 | 点击 Link 按钮，或把 URL 拖入、粘贴到画板 |
| 打开 PDF 或链接 | 双击卡片内容，或点击标题栏的打开按钮 |
| 移动画布 | 拖动空白区域，或使用鼠标、触控板滚动 |
| 缩放画布 | 双指缩放、使用右下角控件，或点击顶部 100% 按钮复位 |
| 移动文本便签 | 按住标题栏任意位置拖动 |
| 移动图片 | 鼠标移入图片后，拖动左上角把手 |
| 缩放便签 | 拖动右下角把手 |
| 编辑标题 | 双击标题文字 |
| 修改颜色或字体大小 | 点击调色板或字号按钮 |
| 折叠或展开 | 点击箭头按钮 |
| 复制便签 | 右键点击便签 |
| 锁定或删除 | 使用标题栏中的对应按钮 |
| 识别图片文字 | 鼠标移入图片，然后点击 OCR 按钮 |
| 创建、切换或重命名 Board | 使用 Board 控件；双击名称可以重命名 |
| 搜索便签 | 点击搜索按钮或按 `⌘F`；按 Return 打开第一条结果 |
| 保存当前 AI 对话 | 在已连接的 AI 客户端中说“把这段聊天保存到 Pinboard” |
| 切换 Board / Desktop | 按 `⌥ Space` |
| 最大化或恢复窗口 | 双击窗口上边缘 |

## MCP 集成

MCP 可以让 AI Agent 直接创建便签，并把有价值的对话归档到 Pinboard。Chat 的整理规则已经写进 MCP：Agent 会根据当前对话自动生成标题、整理 Markdown 摘要并识别来源，不需要用户先复制、总结或填写内容。

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

### 第六步：保存当前聊天

你只需要说：

```text
把这段聊天保存到 Pinboard。
```

Agent 会调用 `save_chat` 并自行完成整理。生成的 Chat 便签会以 Markdown 显示摘要，左上角使用 ChatGPT、Claude、Gemini、Cursor 或 Codex 的提供商图标。

| 参数 | 必填 | 说明 |
| --- | --- | --- |
| `title` | 是 | Agent 根据对话生成的简洁标题 |
| `summary_markdown` | 是 | 整理后的对话摘要，最多 20,000 个字符 |
| `provider` | 是 | `chatgpt`、`claude`、`gemini`、`cursor`、`codex` 或 `other`；由 Agent 推断 |
| `share_url` | 否 | 当前上下文中已经存在的真实 HTTP(S) 分享链接 |
| `x`, `y` | 否 | 便签中心位置；两个参数需要一起提供 |

MCP 会明确要求 Agent 不向用户索要手写摘要，也不让用户选择来源。Agent 不能虚构 Share Link；如果当前 AI 客户端能够提供真实分享链接，Pinboard 会把它收进标题栏的链接按钮，否则正常保存不带链接的 Chat 便签。

### MCP 常见问题

- Agent 找不到 `create_note` 或 `save_chat`：确认 MCP 列表中已经出现 `pinboard`，然后重启 Agent 或新建一个任务，让它重新加载工具列表。
- Pinboard 无法打开：确认 command 指向已安装 `Pinboard.app` 内部的辅助程序。
- 电脑中有多个 Pinboard：把 command 指向你希望 Agent 使用的那个应用副本。
