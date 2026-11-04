# 🐾 Puppy Pomodoro for iPhone

A focus clock with Pork, a fluffy white dog with gray ears and a navy harness. Same rules as the Safari version (`puppy-pomodoro/` on the `claude/pensive-cori-8n9m7p` branch), made for iPhone.

**Version 5.1.1** · needs iOS 17 or newer and a Mac with Xcode 16 or newer. Every version is also saved as its own zip in [`../puppy-pomodoro-iphone-versions`](../puppy-pomodoro-iphone-versions).

## How it works

1. **Idle**: set Focus minutes (25) and Break minutes (5), tap **▶ Start focus**.
2. **Focus**: the clock counts down. Pork naps on his purple bed (Zzz). Every app except your *focus apps* shows Pork's blocked-app screen, and Safari only opens *focus sites*.
3. **Focus goal reached**: no automatic break. The clock counts up in gold (**+00:01, +00:02…**), a bone appears next to the bed, and a notification says *"Focus goal reached! Pork earned a treat."* 1 treat for the goal, plus 1 bonus treat for every 5 minutes of extra focus (*"Pork earned 🦴🦴 · next treat in 03:12"*).
4. **Break**: starts when you open a blocked app and tap **Start my break** on Pork's screen (or tap **Take a break** in the app, on the Lock Screen or on the notification). The treats go into the jar (*"Break time! Pork got 🧀🍪"*). Pork sits by the glass door looking outside.
5. **Break is over**: the clock goes negative in red (−00:01…). The first 2 minutes Pork paces back and forth (*"Can we go out? 🥺"*), then he stands up and scratches the door (*"Woof! Let me out!"*, with the scratching sound and paw smudges on the glass). Notifications keep coming (*"Pork is scratching the door!"*), and every non-focus app shows Pork's screen with **🐾 End the fun — let Pork out**.
6. **Let Pork out**: the door opens, Pork runs outside and the next focus starts. Next focus = focus minutes + how late the break was (25:00 + 1:36 late = **26:36**).

Also: **Pause / Resume**, **Stop** (still gives treats if past the goal), **Back to focus now** during the break.

## What's different on iPhone

An iPhone app can't close other apps or draw on top of them, so each Safari feature has an iPhone version:

| Safari version | iPhone version |
|---|---|
| Non-focus tabs close when focus starts; non-focus sites are sent back to Pork | **Screen Time blocking**: every app except your focus apps shows Pork's screen; Safari only opens focus sites |
| After the goal, opening a non-focus site starts the break | Opening a blocked app after the goal shows *"Focus goal reached! 🦴"* with **Start my break**; tapping it starts the break and opens the app |
| Pork's window on top of every page when the break is over | Blocked apps show Pork's screen with **🐾 Let Pork out**, plus repeated notifications with a **Let Pork out** button and the scratching sound |
| Time on the toolbar icon (green `24m`, gold `+3m`, blue `4m`, red `-2m`, `\|\|`) | **Live Activity** on the Lock Screen and in the Dynamic Island: Pork + the clock in the same colors, with a button (Pause, Take a break, Back to focus, Let Pork out) |
| Message on the page | Notifications |
| — | **Home Screen and Lock Screen widgets** with Pork and the clock |
| — | **Pork's check-ins** (2.0.0): after 5 min on distraction apps a Pork reminder, after 10 min your to-dos; a Calendar event on now shows right away as a big sticky note |
| — | **To-dos as sticky notes** from Apple Reminders (2.0.0) |

## New features and changes for the iPhone version

**5.1.0: the Pork widget shows what to do.** When no Focus session runs, the Pork widget (Home Screen small/medium, Lock Screen rectangle) shows your next event and to-dos instead of the focus clock; during Focus it shows the clock. The one-line widget above the clock keeps today's time and the bedtime countdown. Pork's plan widget now also comes in the small size.

**5.0.0: time limits are separate; everything else is about seeing clearly.**
- **⏱ Time limits** is its own switch in Settings, **off** unless you turn it on, and it stays the way you set it. Off: Pork never blocks anything outside a Focus session. On: the night block and the paw screen (with paw prints) are on, the promise blocks off; changing one of those lasts 1 day.
- **Apps and websites are limited only while a Focus session runs** (Focus tab, or ▶︎ Focus on a to-do).
- **The board, top to bottom**: Tell Pork…, sleep countdown, the event now, **⏱ your time** (distractions today with a bar per app, useful time, this pick-up), **📅 today's calendar** (past events faded, the one on now highlighted), **📝 to-dos this week**, **📅 big picture**, **⏱ time on each project**, inbox, fun list, promise, Pork, yesterday.
- **Time per project**: every to-do sticky note has **▶︎ Focus**. It starts a focus session for that to-do, the Focus tab shows "📌 Lab report · ⏱ 1h20", and the time is added to the project. The note and the board show the total.

**4.1.0: gentle by default, and the big picture.**
- **How strict is Pork** (Settings): the night block and the paw screen at 12 minutes are **on**, the promise blocks are **off** (the morning question and warnings stay). You can change them, but **a change lasts 1 day** and then goes back.
- **📅 Big picture**: every homework, project and quiz due in the next 3 weeks as a bar from today to the due day, red/orange/green by how close it is. Add how many days a task needs to its title (*Lab report ~3d*, *Midterm study (2 days)*): Pork draws its work days, says when to start, and puts it in **Today** (*▶︎ start now · due Thu*) when it's time.
- **💭 Tell Pork…**: a button on the board, a 💭 Lock Screen widget, and Siri ("Hey Siri, tell Pork"). The thought goes to a Reminders list **Inbox**; the board shows it with 📚 / 🔁 / 🎈 buttons to give it a home, and on Sunday at 6 pm Pork asks you to sort the week's thoughts.
- **🐾 Pork's plan widget** (Lock Screen rectangle, Home Screen medium/large): the next event and your to-dos, visible the moment the screen lights up. On the Home Screen tap ○ to tick one off.
- **🎉 Finishing things**: Pork jumps for joy when you tick a to-do; the board and the bedtime message show how many you finished today.
- **💧 Body check**: after 45 minutes on the phone, a gentle "drink some water and stand up?".

**4.0.0: Pork becomes your outside brain.** The app opens on **Pork's board**, where everything is visible: where you should be (a big sticky note for the Calendar event on now or in the next 15 minutes), **your time** (distractions today, useful apps today, this pick-up), to-dos for the week, the fun list, Pork's room and photos, and **⏸ Pause 30 min**. The pomodoro clock moved to the **Focus** tab.
- **Your time is always visible**: the Lock Screen widget shows *📱 1h40 today* (full version; free: how often you opened distraction apps), the Lock Screen / Dynamic Island shows *📱 This pick-up 6:12* counting up while you're on distraction apps.
- **Light friction**: opening a distraction app brings Pork's gate (fun list, the event, your time, **No thanks, go on**). Useful apps (Duo, entrance, mail, Canvas, calendars, health, Uber…) never get a reminder; their time is only shown.
- **This pick-up**: Pork scratches the door after 5 minutes on distractions; after 10 minutes you get your time and to-dos, and then (optional, *Then Pork's paws walk onto the screen*) paw prints drop onto the screen every 15 seconds for 2 minutes; at 12 minutes Pork's paws cover the distraction app (full version) with **Go on, 5 more min**. In the full version these follow real minutes on distraction apps (a locked phone doesn't count).
- **⏸ Pause 30 min** on the board or the Lock Screen: no gates, reminders or blocking; everything comes back by itself.
- **Mac → iPhone**: a **Study** Focus on the Mac (Share Across Devices) turns on the iPhone's Focus too, and two iPhone automations run **Pork: start focus / stop focus**.

- **To-dos as sticky notes** (new in 2.0.0, works with a free account): from Apple Reminders. The **school 2026 fall** list (homework and projects) shows for the next 7 days, one color per day, plus anything overdue. The **routine** list shows for today only. Tap ✓ on a note to mark it done in Reminders. List names can be changed in Settings. Shown on the main screen and in Pork's check-in.
- **Morning promise to Pork** (new in 3.0.0): every day, the first time you pick up the phone after 8 am (not at 8 am sharp: the 8 am notification is silent and just waits on the Lock Screen), the first thing Puppy Pomodoro shows is a full screen that can't be swiped away: *"Good morning! ☀️ Pork wants to know: how much play time do you promise him today?"* (play time = any app or website that isn't a focus app) and *"When do we go to sleep tonight? 🌙"*. Tap **🐾 I promise, Pork!**, then you see **yesterday**: screen time, play time, whether you kept yesterday's promise, time per app (like Apple's Screen Time), and when you put the phone down for the night and picked it up again (sleep). **Start today** starts today's rules:
  - after bedtime only focus apps open until 6 am;
  - full version: play time is counted every 10 minutes; at 3/4 Pork warns you, when it's used up distractions show *"That's today's promise 🐾"* with **15 more minutes**.
  - How it reaches you: an 8 am notification, the pick-up automation opens it, and in the full version every distraction app shows *"Good morning! Make today's promise first"* until you do. (An iPhone app can't pop up over other apps by itself.)
  - Free version: yesterday shows your promise, how often you opened distraction apps, and a sleep guess from the automations; per-app times need the full version.
  - A late bedtime (like 4 or 5 am) counts as the same day (3.1.0): the promise and the play-time count run until bedtime, and "yesterday" in the summary goes from yesterday 8 am to this morning, so the late night is included. Sleep is counted from when you really put the phone down.
  - Sleep times are estimates: Screen Time gives phone use per hour and the first pick-up of the day.
- **Fun list instead of distractions** (new in 3.2.0): a Reminders list called **fun** with things you'd love to do in spare time, each with its link: `Robotics talk open:https://youtu.be/…` (the link can also go in the reminder's notes or URL field). They show as purple sticky notes on the main screen and in Pork's check-in. When you open a distraction app, the automation brings up *"🎈 Something fun instead?"* with those notes first (at most every 15 minutes; **No thanks, go on** lets you continue). Tapping a note opens **only that link** inside Puppy Pomodoro: a YouTube video plays in the YouTube player (no YouTube app, no other videos), a Reddit post or an X account opens but links to anywhere else are stopped. Kindle links open the Kindle app. The rest of YouTube, Reddit and X stays a distraction.
- **"Time to sleep" countdown from 10 pm** (new in 3.3.0): every time you turn on the phone after 10 pm, the top of the Lock Screen shows how long until your bedtime (from today's promise), like *🌙 Sleep in 1:47:12*; after bedtime it switches to *😴 Sleep left 7:02:40*. Add the **Puppy Pomodoro** Lock Screen widget once (inline, above the clock, or the rectangle under it). The main screen and the Lock Screen / Dynamic Island countdown show it too. A bedtime before 10 pm starts the countdown 2 hours earlier; a bedtime after midnight (like 4 am) still starts at 10 pm.
- **Sleep countdown** (3.2.0): after bedtime (12 am, or whatever you promised), or when you tap **I'm going to sleep 🌙** (shown from 9 pm), the main screen and the Lock Screen show how much sleep is left until you get up: **8:30 am on weekdays, 10:30 am on weekends** (Settings). The late-night blocked-app screen says it too. **I'm up ☀️** (or making the morning promise) ends it.
- **The focus clock stops while the phone is locked** (3.0.0): it pauses when you lock the phone and goes on when you unlock it. Pork keeps the app awake with silent audio during focus to notice the lock (your music keeps playing). Setting: *Pause the clock when the phone locks*. If another app takes over the audio (a video with sound), Pork may miss a lock.
- **Yesterday's top distractions** (2.1.0, full version only): every day the main screen and Pork's check-in show your 2 biggest distraction apps from yesterday as big sticky notes ("YouTube 2hr 35min", "foodigame 4hr"), plus yesterday's total screen time and time on distractions. Focus apps don't count. Apple only lets a Screen Time report extension (`Report/`) see these numbers, so it needs the paid account; the Lite version shows a note instead.
- **Big calendar sticky note** (2.0.0): the Apple Calendar event on now (or starting within the hour) shows as a big sticky note at the top.
- **Pork's check-ins** (2.0.0, replaces "Pork says hi"): when you open a distraction app, Pork waits. After **5 min** you get a Pork reminder with one of his photos; after **10 min** a reminder with your to-dos and how many times you opened distraction apps today. Tap it to open the check-in: event note, sticky notes, distraction count, Pork's photos, **Start focus with Pork**. If a Calendar event is on when you open a distraction app, the check-in opens right away. Opening a focus app cancels the reminders. Runs through Shortcuts automations (steps in the app: ⚙︎ → How to set up Shortcuts).
- **12 am Outlook, 6 pm WeChat** (2.0.0): Shortcuts automations ask Pork whether to-dos are left (at 12 am: yesterday's, at 6 pm: today's). If yes, Pork sends the list and the automation opens Outlook / WeChat.
- **Live Activity** (Lock Screen + Dynamic Island) instead of the time on the toolbar icon. It turns gold (+) by itself when you reach the goal and red (−) when the break runs out.
- **Widgets**: small and medium Home Screen widgets (Pork's room), and Lock Screen widgets (clock, `24m` / `+3m` / `−2m`).
- **Blocking** with Screen Time instead of closing tabs: you choose your **focus apps** (for example Safari, ChatGPT, Claude, Gemini, Libby, Books, Messages, Mail, Phone). Websites use the same focus-site list as Safari.
- **Notifications** with buttons: *Take a break* (goal reached) and *Let Pork out* (break over). The scratching sound is the notification sound.
- **Late night: only focus apps** (new in 1.1.0): from 12:00 am to 6:00 am (change the times in Settings), only your focus apps and focus sites open, even without a focus session. Other apps show *"It's late, Pork is asleep 🌙"*. Needs blocking turned on (full version, not Lite).
- **Focus apps** (updated in 2.0.0): Outlook, WeChat, Kindle, Gmail, Google Tasks, Google Calendar, Calendar, Reminders, Handshake, Slack, Messages, Phone, Canvas, Claude, Gemini, ChatGPT (and Puppy Pomodoro). Everything else is a distraction. Pick them in **Choose focus apps** (Apple only lets you pick apps yourself; an app can't add them by name). Their websites are already in the focus-site list: Canvas (`instructure.com`), Handshake, Slack, Notion, Gmail, Google Calendar, Google Tasks, Google Maps, Outlook, Kindle (`read.amazon.com`), Apple Maps, WeChat.
- **Focus sites**: the danmu site (`sssamui.github.io/morethanaproject/danmu`) is a focus site; its YouTube videos play during focus.
- **Treat jar**: tap a treat (instead of hovering) to see when it was earned and whether it was a goal treat or a bonus.
- **Pork's room** in the app is the same drawing and animations as the Safari version.

Not possible on iPhone (Apple doesn't allow it):

- **MIT YouTube channels only**: Screen Time can only allow or block a whole website or app, not one YouTube channel. Lines like `youtube.com/@mitocw` are skipped while blocking. Add `youtube.com` to the focus sites (and the YouTube app to focus apps) if you need YouTube while focusing.
- **Lines with a path allow the whole site**: `sssamui.github.io/morethanaproject/danmu` allows all of `sssamui.github.io` on iPhone (in Safari on the Mac it's only the danmu pages).
- **YouTube players inside focus sites play** (for example videos on the danmu site): the YouTube player (`youtube-nocookie.com`) and video servers are always allowed during focus. They only show videos inside other pages, so YouTube itself stays blocked.
- The blocked-app screen is Apple's layout: a small still picture of Pork and fixed text, no animation.
- The Lock Screen shows Pork scratching the door as soon as the break is over (it can't switch from pacing to scratching after 2 minutes by itself; the app and the blocked-app screen do).
- If you start a break from the blocked-app screen while the app is closed, the Lock Screen clock catches up the next time you open the app or tap a button on the Lock Screen. A notification tells you the break started.

## Install on your iPhone (step by step)

### What you need

- A Mac with **Xcode 16 or newer** (free in the Mac App Store).
- Your iPhone with **iOS 17 or newer** and a USB cable.
- An **Apple Developer Program** membership ($99/year) for app blocking. Apple only allows Screen Time (Family Controls) for paid accounts. Without one, use **PuppyPomodoroLite** (everything except blocking; see the end of this section).

### 1. Get the code on your Mac

1. Open [`puppy-pomodoro-iphone-versions`](../puppy-pomodoro-iphone-versions) on GitHub, click the newest zip (for example `puppy-pomodoro-iphone-v5.1.1.zip`), then click **Download raw file** (the ⬇ button).
2. Double-click the zip in Downloads. You get a folder **puppy-pomodoro-iphone-v5.1.1**.

### 2. Open it in Xcode

1. In that folder, double-click **PuppyPomodoro.xcodeproj**. Xcode opens.
2. If Xcode asks to sign in: **Xcode → Settings → Accounts → +** → **Apple ID** → sign in with the Apple ID of your developer account.

### 3. Pick your team (once)

1. In the left sidebar, click the blue **PuppyPomodoro** icon at the very top.
2. In the middle, under **PROJECT** (not TARGETS), click **PuppyPomodoro**.
3. Click the **Build Settings** tab, then **All** (next to Basic / Customized).
4. In the search box type `Development Team`. Double-click the value next to **Development Team** and choose your team (your name).

All five parts of the app (the app, the widget, and three small Screen Time helpers) use this team.

If Xcode later says an identifier like `com.sssamui.puppypomodoro` *"is not available"*: in the same Build Settings, search `PORK_ID_PREFIX` and change the value to something only you use, like `com.yourname.puppypomodoro`.

### 4. Get your iPhone ready (once)

1. Connect the iPhone to the Mac with the cable. On the iPhone tap **Trust** and enter your passcode.
2. On the iPhone: **Settings → Privacy & Security → Developer Mode → On**. The iPhone restarts; tap **Turn On** after it restarts.

### 5. Run it

1. At the top of Xcode, next to the ▶ button, make sure it says **PuppyPomodoro** and then your iPhone's name (click it to choose your iPhone).
2. Press **▶** (or ⌘R). The first build takes a minute.
3. If the iPhone says *"Untrusted Developer"*: **Settings → General → VPN & Device Management →** tap your developer account → **Trust**. Then press ▶ again.

### 6. Set it up on the iPhone

1. Open **Puppy Pomodoro** and tap **Allow** for notifications.
2. Tap the ⚙︎ (top right) → **Block distractions during focus** → **Continue** and confirm with Face ID or your passcode.
3. Tap **Choose focus apps…** and pick the apps you may use while focusing and late at night: **Safari** (for focus sites), Kindle, Outlook, Handshake, Slack, Phone, Messages, Canvas, Google Calendar, Google Tasks, Calendar, Reminders, Notes, Notion, Gmail, Clock, Claude, ChatGPT, Gemini, Maps, WeChat, Puppy Pomodoro. Use the search box at the top of the list to find each one. Tap **Done**.
4. **Only focus apps late at night** is on (12:00 am–6:00 am). Change **From** / **Until** if you like.
5. **Pork says hi**: in the Photos app make an album called **Pork** and add Pork's photos and videos. (Or pick another album in Settings → *Album in Photos*.) The first time, allow Photos access.
6. Tap **Done** to save.

### 7. Turn on "Pork says hi" (Shortcuts automation, once)

1. Open the **Shortcuts** app → **Automation** tab (bottom) → **+** (top right) or **New Automation**.
2. Scroll down and tap **App**.
3. Tap **Choose** and select every app you want Pork to greet you in. Don't select Phone, Messages, Mail or Puppy Pomodoro. Tap **Done**.
4. Keep **Is Opened** checked. Choose **Run Immediately** and turn off **Notify When Run**. Tap **Next**.
5. Tap **New Blank Automation** → **Add Action** → search **Should Pork say hi** → tap it.
6. Tap the search bar at the bottom, search **If**, tap it. It should say *If Should Pork say hi is true*. If it doesn't, tap the condition and choose **is true**.
7. Search **Say hi to Pork** and drag it between **If** and **Otherwise**. Tap **Done** (top right).

These steps are also in the app: ⚙︎ → **How to turn it on (Shortcuts)**.

### 8. Add the widgets

- **Lock Screen: Pork's plan** (next event + to-dos, seen as soon as the screen lights up): touch and hold the Lock Screen → **Customize** → **Lock Screen** → tap the area under the clock → **Puppy Pomodoro** → **Pork's plan**. Add the round **💭 Tell Pork** next to it if you like.
- **Lock Screen (for the "time to sleep" countdown)**: touch and hold the Lock Screen → **Customize** → **Lock Screen**. Tap the line **above the clock** (the date) and choose **Puppy Pomodoro** for the one-line countdown, and/or tap the area **under the clock** and add the Puppy Pomodoro rectangle. Tap **Done**.
- **Home Screen**: touch and hold an empty spot → **Edit** (top left) → **Add Widget** → search **Puppy Pomodoro** → pick small or medium → **Add Widget**.
- The **Live Activity** (Lock Screen + Dynamic Island) appears by itself when you start a focus.

### Without a paid developer account: PuppyPomodoroLite

Open **PuppyPomodoroLite.xcodeproj** instead of PuppyPomodoro.xcodeproj and do the same steps (pick your Personal Team in step 3). Everything works except blocking apps and websites. With a free account the app stops opening after 7 days; press ▶ in Xcode again to renew it. (With a paid account it lasts a year.)

## Settings

⚙︎ in the top right:

- Focus minutes, break minutes, minutes of extra focus per bonus treat, scratching sound on/off
- Blocking (Screen Time) on/off, focus apps, only focus apps late at night (from / until)
- Focus sites, one per line (`mit.edu` also covers `ocw.mit.edu`). If you installed 1.0.0 and saved your settings, add `sssamui.github.io/morethanaproject/danmu` here yourself (new defaults only apply to a fresh install).
- Pork says hi: on/off, album, how long, how long Pork leaves you alone after *Yes, continue*, videos with or without sound, **Try it now**
- Empty treat jar

## Files

| Folder / file | What it is |
|---|---|
| `PuppyPomodoro.xcodeproj` | The Xcode project (app + widget + Screen Time helpers) |
| `PuppyPomodoroLite.xcodeproj` | Same app without Screen Time blocking, for free Apple accounts |
| `App/` | The app: main screen, Pork's room (`room.html`), treat jar, settings, *Pork says hi*, Shortcuts actions, scratching sound |
| `Shared/` | Used by every part: the timer and treats (`PorkModel.swift`), commands, notifications, Screen Time blocking, colors, Pork's pictures (`PorkArt.xcassets`) |
| `LiveShared/` | Live Activity data and its buttons (app + widget) |
| `Widget/` | Home Screen / Lock Screen widgets and the Live Activity |
| `ShieldConfig/` | Pork's blocked-app screen |
| `ShieldAction/` | Its buttons (**Start my break**, **Let Pork out**) |
| `Report/` | Screen Time report: yesterday's 2 biggest distractions and screen time (full version) |
| `Monitor/` | Wakes up at the focus goal and when the break runs out to update the blocked-app screen |
| `Config/` | Info.plist and entitlement files |
| `tools/` | For making changes: `pork.js` (Pork's drawing, from the Safari version), `build_room.py` (makes `App/room.html`), `render_art.mjs` (makes Pork's pictures and the app icon), `make_scratch_sound.py`, `make_xcodeproj.py` (makes both Xcode projects) |
