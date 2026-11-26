# 🐾 Puppy Pomodoro for iPhone

Pork, a fluffy white dog with gray ears and a navy harness, helps you see your day: what to do, where to be, where your time goes, and what's on your mind.

**Version 6.0.0** · needs iOS 17 or newer, a Mac with Xcode 16 or newer, and a paid Apple Developer account (for Screen Time). Every version is also saved as its own zip in [`../puppy-pomodoro-iphone-versions`](../puppy-pomodoro-iphone-versions).

## The three tabs

### 📝 Reminder
- **Where you should be**: the Calendar event on now (or starting within 15 minutes) as a big yellow sticky note at the top, and **📅 today's calendar** (past events faded, the one on now highlighted). Pork reminds you **15 minutes before** each event.
- **What to do**: sticky notes from Apple Reminders. The **school 2026 fall** list shows for the next 7 days (one color per day, plus anything overdue); the **routine** list shows for today only. Tap ✓ to tick one off (Pork jumps for joy) or **▶︎ Focus** to count focus time on it.
- **📅 Big picture**: everything due in the next 3 weeks as bars. Add how many days a task needs to its title (*Lab report ~3d*) and it shows up in Today when it's time to start.
- **💭 Tell Pork…**: get a thought out of your head in 2 seconds (also a Lock Screen widget and "Hey Siri, tell Pork"). It goes to your Reminders **Inbox** list; sort it later with 📚 / 🔁.

### ⏱ Tracker
- **Your time today, app by app**: every app you used today with its icon and time, longest first (up to 12). Distractions in **red**, focus apps in **green**, with the totals at the top. Fresh numbers each time you open the app. Dark text on light paper, so it reads well in Dark Mode.
- **📱 Pick-ups today**: how many times you picked up the phone (each diary check-in is one), how many you wrote and skipped.
- **📌 Yesterday's top distractions** as two sticky notes, and yesterday's screen time.
- **⏱ Time on each project** (from ▶︎ Focus on a sticky note).
- Only facts: nothing here blocks anything, and nothing scolds you.

### 📔 Diary (the unlock check)
- **When you open an app, Pork's screen asks first**: *"Hi! Pork wants to hear from you 🐾 Take a photo or write Pork one sentence."*
  1. Tap **✏️ Write to Pork**. A notification appears at the top of the screen (Apple doesn't let this screen open an app itself).
  2. Tap the notification. Pork's diary box opens with the keyboard ready and a small question (*"What are you about to do?"*, *"How's your energy?"*…).
  3. Write anything (even "ok") or take a photo, tap **Save 🐾**. One of Pork's photos says thank you, and your apps open.
- **"Not now"** on Pork's screen or in the box always lets you straight in. It's saved as *⏭ skipped* with the time, no guilt.
- **Every entry gets the date and time automatically**: when the check started (you picked up the phone and opened an app).
- **It asks again every time you pick up the phone**: Pork notices when you lock the phone. Locked for more than **1 minute** → the next app you open asks again (back within a minute, e.g. the screen timed out while reading: no new check). If iOS closed Pork in the background, the check comes back after **20 minutes** anyway.
- **Never asks**: the apps you pick in Settings (Puppy Pomodoro, Messages, Maps, Wallet, Camera, your authenticator and banking apps…), plus Phone and Settings. Checking the time, the Lock Screen, notifications and widgets never ask either.
- **Skip today** (Settings) turns it off until midnight.
- **The Diary tab**: every day newest first, each entry with its time; *"🐾 5 of the last 7 days"* (missing a day never resets anything: *"welcome back"*); *"One week ago you wrote…"*; *"This week: 41 pick-ups · most around 11 pm"*.
- **Levels** (Settings → What Pork asks): 1 a photo or one sentence (now) → 2 one sentence → 3 how you feel + one sentence → 4 a short paragraph. You choose when; after 7 days in a row Pork only suggests the next level. Going back is one tap.
- **Where it's saved**: inside the app, and a readable copy in the **Files** app: one file per day (`2026-11-26.md`) and a Photos folder, in **On My iPhone → Puppy Pomodoro → Pork Diary**. Turn on iCloud for the app (optional, below) and the copy goes to **iCloud Drive → Pork Diary** instead, where it survives deleting the app and shows on your Mac.

### ⏱ Focus clock (kept for the Mac, later)
The pomodoro clock with Pork, treats and the treat jar opens from the **⏱** button at the top left. While a focus session runs, a bar with the clock shows at the bottom of every tab, and (only then) every app except your focus apps shows Pork's screen and Safari only opens focus sites. It will be linked with the Safari extension in a later version.

## What's gone in 6.0
The morning promise (play-time target), bedtime and sleep countdowns, the sleep guess, the late-night block, the paw prints and paw screen, "15 more minutes", the fun list, Pork's distraction check-ins and the Shortcuts automations they needed. Version 6 takes down anything they left behind (blocks, schedules, repeating notifications) the first time it opens. **Delete your old Pork automations in Shortcuts** (Automation tab: the ones running *Pork: distraction app opened*, *Pork: focus app opened*, *Pork: to-dos left?*, *Show Pork's check-in*); they no longer exist.

## Install on your iPhone (step by step)

### 1. Get the code on your Mac
1. Open [`puppy-pomodoro-iphone-versions`](../puppy-pomodoro-iphone-versions) on GitHub, click `puppy-pomodoro-iphone-v6.0.0.zip`, then **Download raw file** (the ⬇ button).
2. Double-click the zip in Downloads. You get a folder **puppy-pomodoro-iphone-v6.0.0**.

### 2. Open it and pick your team
1. Double-click **PuppyPomodoro.xcodeproj** in that folder.
2. In the left sidebar, click the blue **PuppyPomodoro** icon at the very top → under **PROJECT** click **PuppyPomodoro** → **Build Settings** → **All** → search `Development Team` → choose **KEVIN LIU**.
3. Check each target under **TARGETS** → **Signing & Capabilities**: **Team = KEVIN LIU**. A yellow note about Family Controls (Development) is fine.

### 3. Run it
1. Connect the iPhone, choose it next to the ▶ button at the top (for example **Kevin's iPhone**), and press **▶**.
2. If the iPhone says *"Untrusted Developer"*: **Settings → General → VPN & Device Management →** your account → **Trust**, then ▶ again.

### 4. Set it up on the iPhone (about 2 minutes)
1. Open **Puppy Pomodoro**, tap **Allow** for notifications.
2. **Reminder** tab: tap **Allow Reminders & Calendar**.
3. **Tracker** tab: tap **Allow Screen Time** and confirm with Face ID.
4. ⚙︎ (top right) → **Choose apps that never ask…** → pick **Puppy Pomodoro** first (use the search box), then Messages, Maps, Wallet, Camera, your authenticator and banking apps → **Done**.
5. ⚙︎ → **Choose focus apps…** → your school and work apps (Outlook, Canvas, Kindle, Notion, Slack, Gmail, Google Calendar, Claude…) → **Done**. They show green in the tracker.
6. ⚙︎ → turn on **Ask when I open an app**. Optional: pick **Pork's album in Photos** (make an album called **Pork** with his photos). Tap **Done**.

The check starts after the next time you lock the phone.

### 5. Optional: keep the diary in iCloud Drive
1. In Xcode, click **PuppyPomodoro** under **TARGETS** → **Signing & Capabilities** → **+ Capability** → **iCloud**.
2. Tick **iCloud Documents**. Under **Containers** click **+** and type `iCloud.com.sssamui.puppypomodoro`.
3. Press ▶ again. New diary days now go to **iCloud Drive → Pork Diary**.

### 6. Widgets
- **Lock Screen**: touch and hold the Lock Screen → **Customize** → **Lock Screen** → tap the area under the clock → **Puppy Pomodoro** → **Pork's plan** (next event + to-dos). Add **💭 Tell Pork** too if you like.
- **Home Screen**: touch and hold → **Edit** → **Add Widget** → **Puppy Pomodoro**.
- Your installed app keeps working for 1 year with the paid account; then press ▶ in Xcode again.

## Settings
- **🔒 Unlock check and diary**: on/off, apps that never ask, what Pork asks (level), skip today; locked less than *1 min*: no new check; ask again after *20 min* anyway; notice when the phone locks (uses a little battery; off = only the 20-minute backup); Pork's album.
- **⏱ Tracker**: Screen Time, focus apps.
- **📝 Reminder**: your Reminders list names (school, routine, inbox).
- **⏱ Focus clock**: focus / break / bonus minutes, scratching sound, pause on lock, focus sites.

## Not possible on iPhone (Apple doesn't allow it)
- No app can appear at the moment you unlock the phone; Pork's screen appears when you open an app.
- Pork's screen can't have a text box or a camera and can't open Pork itself, so it sends a notification you tap.
- iPhone apps aren't told when the phone locks; Pork stays awake with silent audio to notice it (your music keeps playing). If iOS closes Pork anyway, the 20-minute backup takes over.
- Apple's Journal and Notes apps don't let other apps write into them, so the diary lives in Pork and in Files.

## Files

| Folder / file | What it is |
|---|---|
| `PuppyPomodoro.xcodeproj` | The Xcode project (app + widgets + Screen Time helpers) |
| `App/` | The app: the three tabs (`ReminderTab`, `TrackerTab`, `DiaryTab`), the diary box (`WriteView`), the Files copy (`DiaryExport`), the lock watcher, settings, the focus clock, Pork's room |
| `Shared/` | Used by the app and its helpers: the unlock check (`Gate.swift`), the diary (`Diary.swift`), the focus clock and treats, notifications, Screen Time, Pork's pictures |
| `Common/` | Small helpers, also used by the Screen Time report |
| `LiveShared/` | Live Activity data and its buttons |
| `Widget/` | Home Screen / Lock Screen widgets and the Live Activity |
| `ShieldConfig/` | Pork's screen ("Pork wants to hear from you", and the focus clock's screen) |
| `ShieldAction/` | Its buttons (**Write to Pork**, **Not now**, **Start my break**, **Let Pork out**) |
| `Report/` | Screen Time report: today's time per app, yesterday's top distractions |
| `Monitor/` | Wakes up for the 20-minute backup check, at midnight, and for the focus clock |
| `Config/` | Info.plist and entitlement files |
| `tools/` | For making changes: `make_xcodeproj.py` (makes the Xcode project), Pork's drawing and sound tools |
