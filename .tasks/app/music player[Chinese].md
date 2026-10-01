# macOS Native Music Player

开发一款 macOS 原生音乐播放器， UI 视觉风格参考 Apple Music，但不能使用 Apple 的 Logo、图标、字体等任何受版权保护的内容。

## 功能要求
- **主界面**：包含精选专辑推荐网格、推荐歌单与艺术家浏览页面。
- **播放控制**：底部固定播放控制栏，支持进度条拖拽、音量调节、暂停/播放与上一首/下一首。
- **迷你模式**：支持一键切换至独立浮动 Mini Player 迷你窗口模式。
- **队列与收藏**：包含“接下来播放（Up Next）”队列管理与实时红心收藏（Favorite）状态切换。
- **UI 细节**：支持侧边栏（Sidebar）一键展开/折叠，界面采用原生 macOS 磨砂玻璃（AppKit / SwiftUI Material）风格。
- **音频处理**：集成本地合成音频源，在无外部文件接入时支持示范音源正常播放。

**执行说明：** 以 Swift Package（Package.swift + Sources/）形式交付，可在仅安装 Command Line Tools 的环境下通过 `swift build` / `swift run` 编译运行（本机未安装完整 Xcode），同时可直接用 Xcode 打开。
