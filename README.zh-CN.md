# Markdown Quick Look

[English](README.md) | [简体中文](README.zh-CN.md)

一个轻量、原生的 macOS Markdown Quick Look 预览扩展。

在 Finder 中选中 `.md` 或 `.markdown` 文件，按下空格，即可像系统自带文件预览一样查看 Markdown 内容，无需打开完整编辑器。

## 特点

- 原生 macOS Quick Look 扩展
- 不使用 WebView，预览更轻量
- 无网络请求、无遥测、无远程资源加载
- 支持常见 Markdown 样式渲染
- 大文件自动降级为轻量文本预览，避免卡顿
- 安装后可直接在 Finder 中按空格预览

## 系统要求

- macOS 13 Ventura 或更高版本
- Xcode 26.2 或较新的完整 Xcode
- Swift 6

如果当前命令行开发目录仍指向 Command Line Tools，也可以直接使用下面的完整 Xcode 路径构建，不需要修改全局 `xcode-select` 设置。

## 构建

运行测试：

```bash
swift test
```

使用完整 Xcode 构建 macOS App 和 Quick Look 扩展：

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project MarkdownQuickLook.xcodeproj \
  -scheme MarkdownQuickLook \
  -configuration Debug \
  -derivedDataPath .build/XcodeDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

如果你更习惯使用 Xcode 图形界面，可以先切换到完整 Xcode：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
open MarkdownQuickLook.xcodeproj
```

## 在 Finder 中测试

1. 构建 `MarkdownQuickLook` scheme。
2. 从 Xcode 运行一次容器 App。
3. 在 Finder 中选中 `Samples/` 里的 Markdown 文件。
4. 按空格打开 Quick Look 预览。

如果 Finder 仍然显示旧预览，可以刷新 Quick Look 缓存：

```bash
qlmanage -r
qlmanage -r cache
```

也可以在 App 构建并注册后，通过终端测试：

```bash
qlmanage -p Samples/basic.md
```

## 支持的 Markdown

当前版本支持常见 Markdown 预览能力：

- 标题
- 段落
- 引用块
- 有序列表、无序列表和任务列表
- 加粗、斜体、加粗斜体、行内代码、链接、自动链接、裸 URL 和删除线
- 学术墨蓝语义配色主题
- 本地相对图片渲染
- 反引号或波浪线围栏代码块
- 表格
- Mermaid `xychart-beta`、`pie`、`quadrantChart` 和 `timeline` 图表
- 分隔线
- Setext 风格标题

远程图片不会被加载。类似 `https://example.com/image.png` 的远程资源会以安全文本方式显示，不会发起网络请求。本地图片会限制文件体积和显示尺寸，避免影响 Finder 预览流畅度。

## 大文件策略

普通 Markdown 文件会完整读取并使用 Markdown 样式渲染。

较大的 Markdown 文件会完整读取，但会降级为轻量文本预览，避免复杂表格和大量样式布局影响 Finder Quick Look 的流畅度。

## 示例文件

- `Samples/basic.md`
- `Samples/local-image.md`
- `Samples/code-and-table.md`
- `Samples/missing-image.md`
- `Samples/remote-image.md`
