# 悦听 (YueTing) — macOS 原生音乐播放器（中文界面）

一款以 SwiftUI + AVFoundation 编写的 macOS 原生音乐播放器，视觉风格参考 Apple
Music 的布局思路，但**不包含任何 Apple 的 Logo、图标或字体**——所有图标均为本
项目手绘的矢量图形（见 `Glyphs.swift`），完全不依赖 SF Symbols；界面文案使用
系统默认中文字体渲染。以 Swift Package 形式交付，只需 Command Line Tools 即
可编译运行，无需完整 Xcode。

## 环境要求

- macOS 14 及以上
- Swift 6.1 / Xcode Command Line Tools（`xcode-select -p` 应指向
  `/Library/Developer/CommandLineTools`，安装了完整 Xcode 也可以）

> **工具链提示：** 如果 `swift build` 报 "this SDK is not supported by the compiler"，说明 Command Line Tools 安装不匹配。重新安装（`sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`）即可解决；本包本身可以正常编译（2026-10-01 已验证）。

## 运行方式

```sh
cd music-player-cn
swift run
```

只想编译不启动的话用 `swift build` 即可。也可以直接用 Xcode 打开：
`open Package.swift`。

### 如果 `swift build` 报 "Invalid manifest" / undefined symbol 错误

部分 Command Line Tools 安装（本机为 CLT 16.3）自带的 `PackageDescription`
清单 API 存在内部不一致：`.private.swiftinterface` 类型检查解析出的初始化器
签名与 `libPackageDescription.dylib` 实际导出的符号不匹配，导致**任何**
`Package.swift`（哪怉最简单的一行也一样）都会在链接阶段报：

```
Undefined symbols for architecture arm64:
  "PackageDescription.Package.__allocating_init(...)"
```

这是环境 / 工具链本身的问题，与本包代码无关。解决方法：

```sh
cat > /tmp/fix.yaml <<'EOF'
{"version":0,"case-sensitive":"false","roots":[{"type":"directory","name":"/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule","contents":[
{"type":"file","name":"arm64-apple-macos.private.swiftinterface","external-contents":"/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule/arm64-apple-macos.swiftinterface"},
{"type":"file","name":"x86_64-apple-macos.private.swiftinterface","external-contents":"/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule/x86_64-apple-macos.swiftinterface"}]}]}
EOF
mkdir -p /tmp/mc-cn
swift build \
  -Xbuild-tools-swiftc -vfsoverlay -Xbuild-tools-swiftc /tmp/fix.yaml \
  -Xbuild-tools-swiftc -module-cache-path -Xbuild-tools-swiftc /tmp/mc-cn
```

两个参数（VFS overlay 重定向 + 为清单构建单独指定全新的模块缓存目录）需要
**同时**使用，缺一不可。如果你的环境没有这个 bug，直接 `swift build` /
`swift run` 即可。

说明：仅安装 Command Line Tools（没有完整 Xcode）时，首次编译这种带有大量
`Canvas` 自绘图形代码的 SwiftUI 目标可能需要数分钟——这是较慢的类型检查路径
导致的，属于正常现象，不是卡死。

## 首次启动会发生什么

首次启动时，应用会在代码中实时合成 12 首示范曲目（程序化生成的合成器音乐，
覆盖 6 个虚构“专辑”），并写入
`~/Library/Application Support/YueTingPlayer/Samples-v1/` 下的 WAV 文件；
之后的启动会直接复用这些已生成的文件。同时预置了 4 个推荐歌单
（深夜电台 / 专注时刻 / 清晨咖啡 / 律动节拍）。

## 功能对照

- **精选主界面**：精选专辑推荐网格、推荐歌单卡片、艺术家发现区域（`HomeView`）。
- **播放控制栏**：底部固定栏，含进度条拖拽、音量调节、播放/暂停、上一首/
  下一首，磨砂玻璃（`NSVisualEffectView` / SwiftUI Material）背景。
- **迷你模式**：`⌥⌘M` 或播放栏按钮一键切换到独立浮动 Mini Player 窗口
  （`.floating` 层级、可拖动、无标题栏）。
- **接下来播放（Up Next）队列**：右侧滑出面板，支持拖动排序、移除单曲、
  一键清空、双击跳播。
- **实时收藏（Favorite）**：任意歌曲行 / 播放栏 / 迷你窗口的红心按钮均可
  即时切换，状态持久化在 `UserDefaults`。
- **侧边栏一键展开/折叠**：`⌃⌘S` 或顶部按钮，带弹簧动画。
- **本地合成音频源**：`ToneSynth.swift` 纯代码生成音频，无需任何外部音频
  文件即可完整试听。
- **无 Apple 版权内容**：所有图标为 `Glyphs.swift` 中手绘的 `Path`/`Shape`
  矢量图形；专辑封面为 `ArtworkView.swift` 程序化生成的渐变/几何图案；未使用
  SF Symbols、Apple 品牌字体或任何 Apple 素材。

## 项目结构

```
Package.swift
Sources/MusicPlayerCN/
  ToneSynth.swift     – 确定性程序化音频合成器 + WAV 编码
  Models.swift         – Track / Playlist / Album / Artist / Route 数据模型
  LibraryStore.swift    – 示范曲目生成、收藏状态、歌单数据
  PlayerEngine.swift    – 基于 AVAudioPlayer 的播放队列引擎（Up Next）
  Glyphs.swift          – 全部自绘矢量图标（不使用 SF Symbols）与 App 图形标识
  ArtworkView.swift     – 程序化专辑封面渲染（SwiftUI Canvas）
  App.swift             – App 入口、主题、窗口场景、AppKit 磨砂玻璃封装
  MainView.swift         – 侧边栏、顶部栏、路由、折叠/搜索逻辑
  LibraryViews.swift     – 首页精选、专辑、艺术家、歌曲、收藏、歌单详情页
  PlayerViews.swift      – 播放控制栏、Up Next 面板、迷你播放器
```

## 已知局限

- 不支持导入本地音频文件（本包按需求聚焦于内置合成音源 + 收藏/队列/迷你模式
  等功能；如需导入功能请参考英文版 `music-player` 包中的 `NSOpenPanel` 实现）。
- 迷你播放器使用第二个 SwiftUI `Window` 场景并设置 `.floating` 层级，而非
  `NSPanel`，行为上接近浮动工具窗口但不会像真正的 panel 一样从任务切换器中
  隐藏。
