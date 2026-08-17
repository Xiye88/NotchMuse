# Changelog

## 0.6.0 - 2026-08-17

### Added

- Added Apple Music as a selectable music player alongside Spotify
- Added bilingual player status, permission recovery guidance, and lyrics issue reporting

### Changed

- Routed Spotify and Apple Music through a shared player adapter without changing lyrics matching
- Kept Spotify as the default player for existing users

### Fixed

- Cleared stale lyrics when the selected player stops, exits, or loses Automation permission
- Isolated English self-test assertions from the selected app language

### Notes

- Production Matcher scores, thresholds, Provider order, retry, and normalization are unchanged
- The release remains an unsigned Apple Silicon beta for macOS 14 or later

## 0.3.1 - 2026-07-26

### Added

- Added DEBUG-only matcher decision logging for local failure analysis
- Added official Status Bar Mode and Notch Mode demo videos

### Changed

- Long lyrics now scroll left once, stop at the maximum offset, and reset for
  the next line
- Replaced Pause Lyrics with clearer Hide Lyrics and Show Lyrics actions
- Kept Spotify polling active while lyrics are hidden so showing lyrics resumes
  at the current song position

### Fixed

- Made the Notch and overlay lyrics window click-through during normal use
- Removed the incompatible Hide on Hover setting

### Notes

- Production matching scores, thresholds, provider order, and retry behavior
  are unchanged
- The release remains an unsigned Apple Silicon beta for macOS 14 or later

## 0.3.0-beta - 2026-07-18

### Changed

- Prepared the app for a GitHub Beta Release Candidate
- Updated release build defaults to version `0.3.0-beta`
- Expanded README installation, Gatekeeper, platform, and screenshot guidance
- Tightened the release checklist for DMG, signing, notarization, and manual UX validation

## 0.2.2-beta - 2026-07-16

### Added

- Soda Music lyrics provider
- English and Simplified Chinese app localization

### Changed

- Accessibility permission prompts now run only when Left is explicitly selected
- Accessibility checks and prompts are centralized in `AccessibilityManager`
- Bundle identifier is fixed to `app.notchmuse.mac`
- First-launch guidance now explains Spotify, display modes, appearance settings, and Left-only Accessibility permission
- Settings now labels the width control as Lyrics Width
- Added a clean build, package, and verification release script
- Cached foreground menu geometry to reduce CPU use in the Left status bar layout

## 0.2.1 - In Development

### Added

- Status Bar 和 Notch Mode 共用的宽度档位与 Custom Width
- Auto Detect、Built-in Display 和 External Display 显示目标
- Notch Mode 的 Hide on Hover

### Changed

- 重做三种 Notch 样式为更紧凑的原生 HUD 浮层
- 字体范围扩展为 10–26 pt
- 外接无刘海屏根据真实菜单栏可用区域布局
- Settings 根据当前显示模式隐藏无关选项

### Fixed

- 防止辅助功能授权在设置切换时重复弹出
- 移除歌词进度绘制产生的彩色背景矩形

## 0.2 - In Development

### Added

- Notch Mode 顶部中央歌词显示
- Lyric Only、Song + Lyric 和 Expanded 三种 Notch 样式
- Orange、White、Blue、Purple 和 Green 歌词颜色预设
- 共用的歌词透明度设置

### Changed

- Settings 重新分为 Display、Appearance 和 General
- Left 和 Right 布局归入 Status Bar 模式
- 使用屏幕可见区域自动定位 Notch Mode，避开菜单栏图标

## 0.1.1 Beta - 2026-07-14

### Added

- 原生首次启动引导和 Settings 窗口
- Spotify、歌词状态以及当前歌曲信息
- 登录启动、字体大小和动画速度设置
- Debug 模式的 Spotify 与歌词错误日志
- 可拖入 Applications 安装的 DMG 构建脚本

### Changed

- 优化菜单栏入口、歌词布局和垂直居中
- 优化歌词切换动画与长歌词滚动
- 降低后台 Timer 刷新频率和资源占用
- 改进无歌词、网络失败和 Spotify 不可用提示

### Fixed

- 防止重复启动产生多个 NotchMuse 进程
- 退出时释放 Timer、异步任务和 Overlay 窗口
- 防止切歌后旧歌词结果覆盖当前歌曲
