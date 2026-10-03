# NotchMuse 设置页 UI 改版交接文档（第二版主定稿）

更新时间：2026-09-25
项目：NotchMuse
用途：交接给新的 PM / Codex 执行前确认
状态：UI 改版方向已确定，待新 PM 复核后进入开发

---

# 1. 本次改版结论

NotchMuse 当前设置页功能已经基本完整，但现有界面仍偏“普通设置表单”，信息密度、层级、视觉质感和交互反馈都比较弱。

本次已经产出多版 UI 概念图。

**最终选择第二张方案作为主定稿方向。**

这版的核心特点：

- 左侧 Sidebar 导航
- 顶部实时预览区域
- 中间主体按功能卡片分组
- 右侧/局部保留快速预设与辅助信息
- 更接近成熟 macOS 产品的设置页
- 有更清晰的产品感，而不是单纯堆控件
- 保留当前全部核心功能，不改底层产品逻辑
- 后续可继续扩展更多设置项而不容易变乱

本次改版不是重做 NotchMuse 产品逻辑，而是：

> 在不破坏现有功能的前提下，对 Settings UX、信息架构、实时反馈和视觉层级进行一次完整升级。

---

# 2. 当前设置页已有功能

## 显示
- 显示模式：状态栏 / 刘海模式
- 状态栏位置：左侧 / 右侧
- 显示屏幕：自动检测 / 多屏选择
- 歌词宽度：自动 / 紧凑 / 标准 / 宽 / 自定义

## 外观
- 歌词颜色
- 自定义 Color Picker
- 字体大小
- 动画速度
- 不透明度

当前已经完成：
- Slider 加长
- Numeric Input 可编辑
- Slider 与数字双向同步
- 自定义颜色
- 设置持久化

## 通用
- 音乐播放器
- Auto Detect
- 播放器停止时行为
- 语言
- 登录时启动

---

# 3. 当前 UI 的主要问题

1. 所有设置几乎平铺在同一个窗口里，层级感不足。
2. 左侧大面积留白，没有承担导航作用。
3. 缺少实时预览，用户调颜色、字号、透明度时无法直观看到效果。
4. 显示、外观、通用之间虽然有分割线，但仍然像一个大表单。
5. 控件样式基本都是系统默认组合，产品辨识度较弱。
6. 缺少“快速预设”，第一次使用的用户需要手动理解每个参数。
7. 缺少每个区域独立的恢复默认操作。
8. 部分说明性信息位置不统一。
9. 当前界面功能完整，但视觉上还没有达到正式发布版产品的精致程度。

---

# 4. 主定稿 UI 方向

采用第二张概念图作为主要设计参考。

核心结构：

```text
┌────────────────────────────────────────────┐
│ NotchMuse 设置                              │
├──────────┬─────────────────────────────────┤
│ Sidebar  │ 顶部：实时预览                   │
│          │                                 │
│ 显示     ├─────────────────────────────────┤
│ 外观     │ 显示设置        │ 通用 / 辅助     │
│ 通用     │                 │                 │
│          ├─────────────────┼─────────────────┤
│          │ 外观设置        │ 快速预设        │
└──────────┴─────────────────────────────────┘
```

视觉关键词：

- macOS Native
- Light Mode
- Clean
- Premium
- Calm
- Soft Card
- Clear Hierarchy
- Native Controls
- Subtle Depth
- Minimal Decoration
- Real-time Feedback

不要做成：

- Web Dashboard
- Gaming UI
- Neon
- 重度 Glassmorphism
- 复杂渐变
- 大面积装饰
- 过度动画
- 信息过载

---

# 5. Sidebar

左侧增加固定 Sidebar。

建议项目：

## 显示
说明：歌词显示方式、位置与屏幕。
图标：Monitor / Display

## 外观
说明：字体、颜色与动画效果。
图标：Palette / Appearance

## 通用
说明：播放器与系统行为。
图标：Gear

Sidebar 行为：
- 当前 section 高亮
- 点击后切换对应内容
- 保持原生 macOS 动画
- 不需要网页式路由动画
- 不要复杂侧栏折叠

---

# 6. 顶部实时预览

这是此次改版最重要的新增体验。

## 状态栏预览
模拟真实状态栏歌词效果，可显示：
- 当前歌曲
- 当前歌词
- 当前颜色
- 当前字号
- 当前透明度
- 当前宽度

## 刘海模式预览
模拟 MacBook 刘海区域，显示：
- Notch 区域
- 歌词
- 当前外观设置

## Preview 切换
```text
[ 状态栏预览 ] [ 刘海模式预览 ]
```

切换只改变 Preview，不改变用户正式显示模式。

## 实时响应
以下参数调整后，Preview 必须立即更新：
- 歌词颜色
- 字体大小
- 不透明度
- 歌词宽度
- 显示模式
- 状态栏左右位置

动画速度可以使用示例歌词动画模拟。

---

# 7. 显示设置区域

采用独立 Card。

标题：
```text
显示
设置歌词的显示模式、位置和来源屏幕。
```

包含：
- 显示模式：状态栏 / 刘海模式
- 状态栏位置：左侧 / 右侧
- 显示屏幕：自动检测（推荐）
- 歌词宽度：自动 / 紧凑 / 标准 / 宽 / 自定义

条件行为：
- 刘海模式下，状态栏位置隐藏或 Disable
- 自定义宽度时才显示额外宽度控件

---

# 8. 外观设置区域

独立 Card。

标题：
```text
外观
自定义歌词的视觉效果。
```

## 歌词颜色
保留：
- 预设颜色
- Native macOS Color Picker

建议 UI：
```text
● Orange
● Red
● Pink
● Purple
● Blue
● Cyan
● Green
● White
🌈 Custom
```

Custom 继续调用原生 Color Picker。

---

# 9. Slider 控件

继续保留现有：
- Font Size
- Animation Speed
- Opacity

长 Slider + Numeric Field。

```text
字体大小
────────────●────────────   [ 19 ] pt

动画速度
────────●────────────────   [ 1.0 ] ×

不透明度
──────────────────────●──   [ 100 ] %
```

Numeric Input 必须支持：
- Click
- Keyboard Input
- Enter Confirm
- Value Validation
- Slider Sync

---

# 10. 快速预设

建议第一版提供 4 套。

1. 暖橙动感
2. 清新简约
3. 梦幻柔和
4. 极简纯净

Preset 本质上只是批量修改现有设置：

```text
Color
+
Font Size
+
Animation Speed
+
Opacity
+
可选 Lyrics Width
```

不要创建新的 Style Engine。

用户应用预设后仍可继续手动微调。

---

# 11. 恢复默认

建议支持分区 Reset：

- 显示 → 恢复默认
- 外观 → 恢复默认
- 通用 → 恢复默认

只恢复当前区域。

全局恢复默认可以后续放入 More Menu，不是第一优先级。

---

# 12. Tooltip / Help

以下设置建议增加 Tooltip / Help：

- Auto Detect
- 显示屏幕
- 播放器停止时
- 登录时启动
- 刘海模式

原则：
不要长期显示大量解释文字，只有容易产生误解的项目加帮助说明。

---

# 13. General 区域

包含：

## 音乐播放器
- Auto Detect (Recommended)
- Spotify
- Apple Music
- NetEase Cloud Music

## 播放器停止时
- 隐藏歌词，等待恢复

## 语言
- 简体中文
- English

## 登录时启动
- 标准 macOS Toggle

---

# 14. 交互细节

## Hover
只使用轻微反馈：
- Button background
- Card hover
- Icon tint

不要大面积 Glow。

## Focus
Numeric Input 使用标准 macOS Focus Ring。

## Selected
使用系统 Accent Color，不要硬编码蓝色。

优先使用系统颜色，例如：
```text
NSColor.controlAccentColor
```

## Animation
建议控制在 120–220ms。

仅用于：
- Section 展开
- Preview 切换
- Preset Selection
- Conditional Control

不要做炫技动画。

---

# 15. Window Layout

建议适当增加 Settings Window 宽度。

大致目标：

```text
Width: 1100–1250
Height: 760–850
```

具体数值允许根据 AppKit / SwiftUI 实际情况调整。

---

# 16. Responsive / 小尺寸处理

如果用户缩小窗口：

优先：
1. Preview 缩小
2. 两列变一列
3. Sidebar 保持
4. 不允许 Controls 被严重压缩

不要：
- Slider 重新变得很短
- Numeric Input 被遮挡
- Label 严重断行

---

# 17. 技术原则

本次 UI 改版必须遵守：

## 不重写播放器核心
不要动：
- Spotify Engine
- Apple Music Engine
- NetEase Adapter
- MediaRemote
- Lyrics Provider
- Auto Player Detection

除非 UI 绑定确实需要极小调整。

## 不改变 Settings 数据结构
优先继续使用当前：
- Preferences
- UserDefaults
- Current Settings Model

避免造成：
- 老用户设置丢失
- Settings Migration

## 不破坏当前 Color Picker
现有 Custom Color 已经工作，重新布局即可，不要重写颜色系统。

---

# 18. 开发阶段

## Sprint 1 — Layout Refactor
目标：完成整体结构。

任务：
1. Sidebar
2. Main Content Layout
3. Card Components
4. Top Preview Container
5. 显示 / 外观 / 通用重新布局
6. 统一 spacing
7. 统一 typography
8. 保证现有 controls 全部可操作

第一阶段暂时不要求完整 Preview Logic。

## Sprint 2 — Interaction
任务：
1. Live Preview
2. 状态栏 / 刘海 Preview 切换
3. Appearance Presets
4. Section Reset
5. Tooltips
6. Conditional Settings
7. 实时联动

## Sprint 3 — Polish + QA
任务：
1. Hover
2. Focus
3. Spacing
4. Icon consistency
5. Multi-resolution
6. Localization overflow
7. Persist Settings regression
8. Player regression
9. Release Build

---

# 19. Codex 正式执行 Prompt

```text
# NotchMuse Settings UI Redesign

Act as autonomous developer.
Do not ask for approval for non-destructive decisions.
Proceed with implementation.

## Background

NotchMuse core functionality is already stable.

Current supported playback sources:
- Spotify
- Apple Music
- NetEase Cloud Music
- Auto Player Detection

Current Settings functionality already works:
- Display Mode
- Status Bar Position
- Display Screen
- Lyrics Width
- Lyrics Color
- Native Custom Color Picker
- Font Size
- Animation Speed
- Opacity
- Editable numeric fields
- Player Selection
- Player Stop Behavior
- Language
- Launch at Login

This task is NOT a core functionality rewrite.

The purpose is to redesign the Settings UI and improve UX.

The approved visual direction is the SECOND NotchMuse Settings redesign concept previously reviewed by the product owner.

Use that concept as the primary visual reference.

## Main Product Goal

Transform the current Settings window from a basic settings form into a polished macOS product experience.

Key principles:
- Native macOS feel
- Clean
- Light mode
- Premium but restrained
- Clear information hierarchy
- Real-time feedback
- Minimal unnecessary decoration
- Maintain existing functionality

Do NOT turn this into:
- a web dashboard
- gaming UI
- neon UI
- heavy glassmorphism
- complex visual effects

## Phase 1 — Layout Refactor

Implement a left navigation sidebar:
- 显示
- 外观
- 通用

Each item should use a native/simple SF Symbol style icon.

Selected section should use system accent color.

Reorganize current settings into clearly separated cards:

### 显示
Contains:
- 显示模式
- 状态栏位置
- 显示屏幕
- 歌词宽度

### 外观
Contains:
- 歌词颜色
- Preset color swatches
- Custom Color Picker
- 字体大小
- 动画速度
- 不透明度

### 通用
Contains:
- 音乐播放器
- 播放器停止时
- 语言
- 登录时启动

Do not remove any existing functionality.

## Phase 2 — Live Preview

Add a live preview area near the top.

Support two preview modes:
- 状态栏预览
- 刘海模式预览

The preview should react immediately to:
- lyrics color
- font size
- opacity
- lyrics width
- display mode
- status bar position

Animation speed can use a sample lyric animation.

This preview is visual only.

Changing preview mode must NOT modify the user's actual display mode.

## Phase 3 — Appearance Presets

Add four initial quick appearance presets:

1. 暖橙动感
2. 清新简约
3. 梦幻柔和
4. 极简纯净

Each preset should simply update the existing settings model:
- Color
- Font Size
- Animation Speed
- Opacity
- optional Lyrics Width

Do NOT create a second styling engine.

Users must still be able to manually adjust values after applying a preset.

## Phase 4 — Reset Controls

Add:
- Display section reset
- Appearance section reset
- General section reset

Reset only the current section.

Do not reset unrelated settings.

## Phase 5 — Interaction Details

Add lightweight native interaction feedback:
- hover
- focus ring
- selected state
- helper tooltips

Use system accent colors wherever possible.

Avoid hard-coded visual effects.

## Phase 6 — Conditional Controls

Improve contextual behavior.

Example:

If:
Display Mode == Notch Mode

then Status Bar Position should be hidden or disabled.

If:
Lyrics Width == Custom

show custom width controls.

Otherwise:
hide unnecessary controls.

## Technical Requirements

Do not rewrite:
- Spotify integration
- Apple Music integration
- NetEase integration
- MediaRemote runtime
- Auto Player Detection
- Lyrics provider architecture

Do not break existing Settings persistence.

Existing user preferences must remain valid.

Reuse current Settings model / UserDefaults where possible.

Reuse the existing custom color picker implementation.

## UI Requirements

Use native macOS visual language.

Prefer:
- SF Symbols
- system colors
- native controls
- subtle cards
- consistent spacing
- system typography

Suggested Settings window size:

approximately:
1100–1250 px width
760–850 px height

Adjust based on implementation needs.

## Responsive Behavior

If window size becomes smaller:
- reduce preview size first
- allow two-column layout to collapse into one column
- keep controls usable
- keep sliders reasonably long

Do NOT allow the numeric fields or labels to become clipped.

## QA Requirements

Before completion verify:

### Settings
- all existing settings still work
- settings persist after restart
- custom color persists
- sliders and numeric input remain synchronized
- presets update settings correctly
- reset works correctly

### Preview
- color updates
- font size updates
- opacity updates
- width updates
- preview mode switching works

### Regression
Verify:
- Spotify
- Apple Music
- NetEase
- Auto Detect

No playback regression.

## Build / Local Deployment

After implementation:

1. Run self tests
2. Run Debug build
3. Run Release build
4. Generate latest NotchMuse.app
5. Quit currently running /Applications/NotchMuse.app
6. Replace the old local app with the new build
7. Launch /Applications/NotchMuse.app
8. Verify the installed app is the latest build

The user should always be testing the latest local build.

## Git Workflow

After QA:
- create clear commit(s)
- push current candidate branch
- report branch
- report commit hash
- report build number

Do NOT merge main unless explicitly instructed.

## Final Report

Report:
1. UI components changed
2. Files changed
3. Live Preview implementation
4. Preset implementation
5. Reset behavior
6. QA results
7. Build number
8. Commit hash
9. Remaining issues
```

---

# 20. PM 验收标准

新的 PM 需要重点检查：

## 1. 是否仍然像 macOS App
如果明显变成 Web Dashboard：不通过。

## 2. Preview 是否真的有价值
不是放一张假的图片，必须和设置联动。

## 3. 是否破坏原功能
如果以下任一出现问题，都不能接受：
- Apple Music
- 网易云
- Auto Detect
- Settings 保存

## 4. 是否过度设计
NotchMuse 是小型、轻量、长期驻留的 macOS 工具。

Settings 不应该比产品本身更复杂。

---

# 21. 当前推荐优先级

```text
P0
Settings Existing Function Regression

P1
Sidebar
Live Preview
Layout Cards

P1
Appearance Presets
Section Reset

P2
Hover
Tooltip
Micro Animation

P3
更多主题
Preset Import / Export
Advanced Animation Editor
```

---

# 22. 本次不做

本轮不建议加入：

- 主题市场
- 在线主题下载
- Preset 分享
- 高级动画编辑器
- 自定义 Curve Editor
- 拖拽布局编辑
- 插件系统
- 大规模播放器逻辑修改

---

# 23. 新 PM 接手后的第一步

建议新 PM：

1. 查看当前最新版 Settings 实际界面。
2. 查看第二版主定稿概念图。
3. 对照当前代码，确认哪些是纯 UI，哪些需要新增状态绑定。

然后再决定：
- 是否直接执行完整改版
- 或先做 Sprint 1 Prototype

不要重新讨论整个视觉方向。

**当前默认视觉方向已经确定：第二版 UI 概念图。**

如无明显技术问题，应在此基础上继续推进。

---

# 24. 最终产品目标

这次 UI 改版完成后，NotchMuse 设置页应该让用户产生这样的感觉：

> “这是一个真正为 macOS 设计的小工具。”

而不是：

> “这是一个把很多系统控件排在一起的设置窗口。”

核心不是增加更多功能。

核心是：

**让现有已经完成的功能变得更好理解、更容易调整、更有即时反馈，也更像一个正式可发布的 macOS 产品。**
