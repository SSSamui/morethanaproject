# 🐾 Puppy Pomodoro for iPhone

A focus clock with Pork, a fluffy white dog with gray ears and a navy harness. Same rules as the Safari version (`puppy-pomodoro/` on the `claude/pensive-cori-8n9m7p` branch), made for iPhone.

**Version 1.0.1** · needs iOS 17 or newer and a Mac with Xcode 16 or newer. Every version is also saved as its own zip in [`../puppy-pomodoro-iphone-versions`](../puppy-pomodoro-iphone-versions).

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
| — | **Pork says hi**: when you open an app (not Phone, Messages or Mail) and the clock isn't running, Pork's photos and videos from an album play first, then you choose to continue |

## New features and changes for the iPhone version

- **Pork says hi** (new): photos and videos from an album in Photos (default name **Pork**) play for 60 seconds (Settings: 15 s to 10 min). Then: **Yes, continue** (Pork leaves you alone for 15 minutes, changeable), **▶ Start focus with Pork**, **No, I'll put my phone down**, or **Keep watching Pork**. It runs through a Shortcuts automation (steps below), because iPhone apps can't tell when you unlock the phone. If the album is empty, Pork's drawings play instead.
- **Live Activity** (Lock Screen + Dynamic Island) instead of the time on the toolbar icon. It turns gold (+) by itself when you reach the goal and red (−) when the break runs out.
- **Widgets**: small and medium Home Screen widgets (Pork's room), and Lock Screen widgets (clock, `24m` / `+3m` / `−2m`).
- **Blocking** with Screen Time instead of closing tabs: you choose your **focus apps** (for example Safari, ChatGPT, Claude, Gemini, Libby, Books, Messages, Mail, Phone). Websites use the same focus-site list as Safari.
- **Notifications** with buttons: *Take a break* (goal reached) and *Let Pork out* (break over). The scratching sound is the notification sound.
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

1. Open [`puppy-pomodoro-iphone-versions`](../puppy-pomodoro-iphone-versions) on GitHub, click the newest zip (for example `puppy-pomodoro-iphone-v1.0.1.zip`), then click **Download raw file** (the ⬇ button).
2. Double-click the zip in Downloads. You get a folder **puppy-pomodoro-iphone-v1.0.1**.

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
3. Tap **Choose focus apps…** and pick the apps you may use while focusing. Pick **Safari** if you want the focus sites. Also pick Messages, Mail and Phone if you want them. Tap **Done**.
4. **Pork says hi**: in the Photos app make an album called **Pork** and add Pork's photos and videos. (Or pick another album in Settings → *Album in Photos*.) The first time, allow Photos access.
5. Tap **Done** to save.

### 7. Turn on "Pork says hi" (Shortcuts automation, once)

1. Open the **Shortcuts** app → **Automation** tab (bottom) → **+** (top right) or **New Automation**.
2. Scroll down and tap **App**.
3. Tap **Choose** and select every app you want Pork to greet you in. Don't select Phone, Messages, Mail or Puppy Pomodoro. Tap **Done**.
4. Keep **Is Opened** checked. Choose **Run Immediately** and turn off **Notify When Run**. Tap **Next**.
5. Tap **New Blank Automation** → **Add Action** → search **Should Pork say hi** → tap it.
6. Tap the search bar at the bottom, search **If**, tap it. It should say *If Should Pork say hi is true*. If it doesn't, tap the condition and choose **is true**.
7. Search **Say hi to Pork** and drag it between **If** and **Otherwise**. Tap **Done** (top right).

These steps are also in the app: ⚙︎ → **How to turn it on (Shortcuts)**.

### 8. Add the widgets (optional)

- **Home Screen**: touch and hold an empty spot → **Edit** (top left) → **Add Widget** → search **Puppy Pomodoro** → pick small or medium → **Add Widget**.
- **Lock Screen**: touch and hold the Lock Screen → **Customize** → **Lock Screen** → tap the widget area → **Puppy Pomodoro**.
- The **Live Activity** (Lock Screen + Dynamic Island) appears by itself when you start a focus.

### Without a paid developer account: PuppyPomodoroLite

Open **PuppyPomodoroLite.xcodeproj** instead of PuppyPomodoro.xcodeproj and do the same steps (pick your Personal Team in step 3). Everything works except blocking apps and websites. With a free account the app stops opening after 7 days; press ▶ in Xcode again to renew it. (With a paid account it lasts a year.)

## Settings

⚙︎ in the top right:

- Focus minutes, break minutes, minutes of extra focus per bonus treat, scratching sound on/off
- Blocking (Screen Time) on/off, focus apps
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
| `Monitor/` | Wakes up at the focus goal and when the break runs out to update the blocked-app screen |
| `Config/` | Info.plist and entitlement files |
| `tools/` | For making changes: `pork.js` (Pork's drawing, from the Safari version), `build_room.py` (makes `App/room.html`), `render_art.mjs` (makes Pork's pictures and the app icon), `make_scratch_sound.py`, `make_xcodeproj.py` (makes both Xcode projects) |
