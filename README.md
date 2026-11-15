# Habituate

A habit tracker for iPhone. Tick off several habits each day on a weekly grid, see streaks and weekly percentages, and browse a monthly calendar for each habit. Everything is stored on the device with SwiftData. There's no account and no internet connection.

- iOS 17 or later, iPhone, SwiftUI + SwiftData, no third-party libraries
- Home Screen widget with today's habits
- A daily reminder per habit, on that habit's scheduled days
- Light and dark mode, Dynamic Type up to the largest accessibility size, VoiceOver labels on every control

## Project layout

```
Habituate/
  App/            HabituateApp (entry point, test launch switches)
  Models/         Day, WeekdaySet, HabitHistory (all streak/percentage maths), Habit (@Model),
                  HabitDraft/HabitSnapshot, HabitColor, SampleData, HabitStoreFactory
  ViewModels/     HabitStore (every data change), WeekViewModel, HabitEditorViewModel, DayState
  Services/       ReminderScheduler (local notifications)
  Views/          RootView, Week/, Detail/, Editor/, Manage/, Settings/, Components/
  Resources/      Assets.xcassets (app icon, accent colour, launch screen)
HabituateWidget/  Today's Habits widget (reuses Models)
HabituateTests/   Unit tests: dates, streaks, percentages, schedules, store, reminders
HabituateUITests/ UI tests, screenshots and accessibility audits
Config/           Info.plists and entitlements
project.yml       XcodeGen project definition
tools/            make-icons.js, which redraws the app icon and launch logo
.github/workflows/ci.yml  Builds and runs every test on iPhone SE and iPhone Pro Max simulators
```

## 1. Create the Xcode project

You need a Mac with **Xcode 16 or later** (free from the Mac App Store).

1. Open Terminal and install XcodeGen. It turns `project.yml` into an Xcode project, so nobody has to edit project files by hand:
   ```bash
   brew install xcodegen
   ```
   No Homebrew? Install it from https://brew.sh first.
2. Go to the project folder and generate the project:
   ```bash
   cd path/to/Habituate
   xcodegen generate
   ```
3. Open `Habituate.xcodeproj`.

Run `xcodegen generate` again whenever you add or remove files.

## 2. Run the tests

- In Xcode, pick any iPhone simulator at the top of the window and press **⌘U**.
- Or from Terminal:
  ```bash
  xcodebuild test -project Habituate.xcodeproj -scheme Habituate -destination "platform=iOS Simulator,name=iPhone 16"
  ```
  Use any simulator name from `xcrun simctl list devices`.

The UI tests also save screenshots in light mode, dark mode and the largest text size. In Xcode, find them in the Report navigator (⌘9) under the test run.

## 3. Run the app in the simulator

Pick an iPhone simulator and press **⌘R**. On first launch the app adds six sample habits with a few weeks of history, so you can demo it straight away.

**Removing the sample habits:** tap **⋯** (top left) › **Settings** › **Remove Sample Habits**. Habits you added yourself are kept.

## 4. Run the app on your own iPhone

1. Plug in your iPhone and unlock it. On the phone, turn on **Settings › Privacy & Security › Developer Mode** (it restarts).
2. In Xcode, open **Settings › Accounts** and sign in with your Apple ID.
3. Select the **Habituate** project › **Habituate** target › **Signing & Capabilities**:
   - Tick **Automatically manage signing** and choose your **Team**.
   - Change the **Bundle Identifier** to something unique to you, e.g. `com.yourname.habituate`.
4. Do the same for the **HabituateWidget** target, using the app's identifier plus `.widget`, e.g. `com.yourname.habituate.widget`.
5. **App Group (needed for the widget):** both targets use `group.com.habituate.app`.
   - **Paid developer account:** in **Signing & Capabilities** for both targets, change the App Group to `group.com.yourname.habituate`, and change `AppGroup.identifier` in `Habituate/Models/HabitStoreFactory.swift` to match.
   - **Free Apple ID:** free accounts can't use App Groups. Remove the **App Groups** capability from both targets (click the bin icon next to it). The app works fully. The widget will say "Open Habituate to see today's habits here" because it can't read the app's data.
6. Choose your iPhone at the top of the window and press **⌘R**. The first time, open **Settings › General › VPN & Device Management** on the phone and trust your developer certificate.

With a free Apple ID, the app stops opening after 7 days. Run it from Xcode again to renew it.

## Continuous integration

Every push to GitHub runs `.github/workflows/ci.yml` on a GitHub macOS machine. It:

1. builds with Swift warnings treated as errors,
2. runs every unit and UI test on an iPhone SE and an iPhone Pro Max simulator at the same time,
3. uploads the logs, the warnings list and all screenshots as a `results` artifact.

## How the date logic works

- Ticks are stored as calendar **days**, not timestamps. A day is a count of days since 1 January 1970, converted with the Gregorian calendar in the phone's current time zone. Changing time zone or travelling never moves a tick to a different day.
- Weeks run Monday to Sunday.
- **Streak:** scheduled days completed in a row. Days off the schedule are skipped and don't break it. An unticked today doesn't break it until the day is over.
- **Weekly %:** completed ÷ scheduled days. In the current week, only days up to today count.
- **Schedule edits** apply from the day of the edit. Each habit keeps a history of its schedules, so earlier days keep the schedule they had and past streaks and percentages don't change.
- "Today" is re-read at midnight, when the time zone or clock changes, and whenever the app comes back to the foreground.
