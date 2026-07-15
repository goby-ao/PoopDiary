<div align="center">
  <img src="PoopDiary/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-180.png" width="120" alt="PoopDiary app icon">
  <h1>便便超人 · PoopDiary</h1>
  <p>让孩子愿意记录，让家长轻松了解。</p>
  <p><em>Make a private daily routine feel lighter, kinder, and easier to understand.</em></p>

  [中文](#中文) · [English](#english)

  ![iOS 17+](https://img.shields.io/badge/iOS-17%2B-000000?logo=apple)
  ![Swift 5](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)
  ![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0D96F6)
  ![SwiftData](https://img.shields.io/badge/Data-SwiftData-34C759)
</div>

## 中文

便便超人是一款为孩子和家长设计的 iOS 便便记录 App。它把原本有点尴尬、容易忘记的日常记录，变成一次轻松的打卡、一张慢慢点亮的热力图，以及一场每天只能玩一次的清扫挑战。

它不评价孩子，也不制造健康焦虑。孩子只需要诚实记录今天的情况，家长则可以从连续打卡、趋势和月度报告里，更自然地了解生活节奏。

### 产品亮点

- **轻松打卡**：记录今天是否便便、便便量和备注，用吉祥物、动画、音效与触感反馈降低记录门槛。
- **多孩子档案**：为每个孩子保存独立记录，可在首页快速切换。
- **日历与热力图**：通过月历和近期热力图回看每一天，支持补记和修改历史记录。
- **趋势与成就**：查看连续天数、近 7 天和近 30 天趋势、便便量分布、里程碑与成就墙。
- **每日清扫挑战**：完成打卡后解锁三波小游戏，收集贴纸并挑战更高分，让坚持本身更有趣。
- **月报分享**：生成适合分享的月度报告图片，也可以导出 CSV 数据。
- **提醒与家长设置**：支持本地每日提醒、音效和触感开关，以及集中管理孩子档案。
- **数据留在本机**：记录默认保存在设备上的 SwiftData 数据库中，不依赖账号或后端；只有在你主动导出、备份或分享时，数据才会离开 App。

### 为什么做它

身体信号值得被认真对待，但记录这件事不该有压力。便便超人希望用孩子能理解的方式建立习惯，也给家长一份清楚但不过度解读的日常参考。

> 便便超人是生活记录工具，不提供医疗诊断或治疗建议。如有持续不适，请及时咨询专业医护人员。

### 技术实现

- SwiftUI 构建界面
- SwiftData 负责本地持久化
- Swift Charts 展示趋势与分布
- UserNotifications 提供本地每日提醒
- 无第三方依赖，无需账号或自建服务
- 最低支持 iOS 17.0

### 本地运行

1. 克隆仓库：

   ```bash
   git clone https://github.com/goby-ao/PoopDiary.git
   cd PoopDiary
   ```

2. 使用 Xcode 15 或更高版本打开 `PoopDiary.xcodeproj`。
3. 选择 iOS 17+ 模拟器或真机，运行 `PoopDiary` Scheme。

### 项目状态

项目正在持续开发中，欢迎通过 Issue 提交建议或反馈问题。当前 App 界面为简体中文，本 README 同时提供中文和英文介绍。

---

## English

PoopDiary is an iOS poop diary made for children and their parents. It turns an awkward, easy-to-forget routine into a quick check-in, a heatmap that grows day by day, and a playful cleanup challenge available once a day.

The app does not judge children or turn everyday health into a source of anxiety. Children can simply record what happened, while parents get a clearer view of streaks, patterns, and monthly summaries.

### Highlights

- **Friendly daily check-ins:** Record whether a child pooped, the amount, and an optional note. A cheerful mascot, animation, sound, and haptics make the routine approachable.
- **Multiple child profiles:** Keep each child's history separate and switch profiles directly from the home screen.
- **Calendar and heatmaps:** Look back through a monthly calendar or recent activity heatmap, with support for adding and editing past entries.
- **Trends and achievements:** Explore streaks, 7-day and 30-day trends, amount distribution, milestones, and an achievement wall.
- **Daily cleanup challenge:** Finish a check-in to unlock a three-wave mini-game, collect stickers, and chase a new high score.
- **Shareable monthly reports:** Generate a monthly report image or export records as CSV.
- **Reminders and parent settings:** Configure a local daily reminder, sound, haptics, and child profiles in one place.
- **Local-first data:** Records are stored in an on-device SwiftData database with no account or backend required. Data leaves the app only when you choose to export, back up, or share it.

### Why PoopDiary

Body signals deserve attention, but keeping track of them should not feel stressful. PoopDiary helps children build a simple habit in a language they understand, while giving parents useful context without overinterpreting a single day.

> PoopDiary is a lifestyle tracking tool. It does not provide medical diagnosis or treatment advice. Please consult a qualified healthcare professional if symptoms persist.

### Built with

- SwiftUI for the interface
- SwiftData for local persistence
- Swift Charts for trends and distributions
- UserNotifications for local daily reminders
- No third-party dependencies, accounts, or self-hosted services
- iOS 17.0 or later

### Run locally

1. Clone the repository:

   ```bash
   git clone https://github.com/goby-ao/PoopDiary.git
   cd PoopDiary
   ```

2. Open `PoopDiary.xcodeproj` in Xcode 15 or later.
3. Select an iOS 17+ simulator or device and run the `PoopDiary` scheme.

### Project status

PoopDiary is under active development. Issues and thoughtful feedback are welcome. The current app interface is in Simplified Chinese; this README provides both Chinese and English introductions.
