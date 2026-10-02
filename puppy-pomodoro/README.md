# 🐾 Puppy Pomodoro — Safari extension

A Pomodoro clock with a puppy.

- **Focus**: set how long you want to focus and how long your break is. When focus starts, every distraction site (YouTube, TikTok, Instagram, Reddit, game sites, …) is closed. If you open one during focus, the tab is sent back to the puppy.
- **Break**: the puppy plays with its ball while the break counts down.
- **Break is over**: the puppy runs to the door and **scratches it** ("Woof! Let me out!"). The clock keeps going into **negative time** (−00:01, −00:02, …).
- **Let puppy out**: click **🐾 End the fun — let puppy out** (you end the game or distraction). The door opens, the puppy runs outside and a **tree or flower is planted** in your forest. Any distraction tabs are closed.
- **Back to work automatically**: the next focus starts right away and lasts **focus time + the extra time you took on the break**. Example: 25 min focus, break 2:05 over → next focus is 27:05.

What gets planted depends on how fast you came back:

| Back after the break ended | Plant |
|---|---|
| within 1 minute | 🌳 🌲 🌸 🌻 🌷 🌺 🌴 🌹 |
| within 5 minutes | 🌼 🪴 🌿 🍀 |
| later | 🌱 |

The toolbar badge shows the minutes left (green = focus, blue = break, red = minutes over).

## Install in Safari (Mac)

Safari extensions have to be wrapped in a small Mac app. You need **Xcode** (free from the App Store).

1. In Terminal, from this repo:
   ```sh
   xcrun safari-web-extension-converter puppy-pomodoro --app-name "Puppy Pomodoro" --macos-only
   ```
   Xcode opens the new project.
2. In Xcode, press **▶ Run**. A small "Puppy Pomodoro" app opens. You can close it.
3. In Safari: **Settings → Advanced →** turn on **Show features for web developers**.
   Then **Develop → Allow Unsigned Extensions** (you need to do this again after you quit Safari).
4. **Safari → Settings → Extensions →** turn on **Puppy Pomodoro**.
5. Click **Always Allow on Every Website** for Puppy Pomodoro. This lets it see and close distraction tabs. Without it, the clock still works but it can't close sites.
6. Click the paw icon in the toolbar. Use **⤢** to open the puppy in its own tab.

For iPhone/iPad as well, leave out `--macos-only`.

## Settings

Open **Settings** at the bottom of the popup:

- Start the break automatically after focus (on by default)
- Keep distraction sites closed during focus (on by default)
- Open the puppy tab when a session ends, so you notice the puppy at the door (on by default)
- Scratching sound
- Your list of distraction sites, one per line (`youtube.com` also covers `m.youtube.com` etc.)
- Clear forest

## Files

| File | What it does |
|---|---|
| `manifest.json` | Extension setup (Manifest V3) |
| `background.js` | The timer, phase changes, closing/blocking distraction tabs, badge |
| `app.html` / `app.css` / `app.js` | The popup and puppy tab: clock, room with puppy and door, forest, settings |

It also runs in Chrome: `chrome://extensions` → Developer mode → **Load unpacked** → pick this folder.
