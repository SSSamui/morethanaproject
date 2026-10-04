# 🐾 Puppy Pomodoro — Safari extension

A focus clock with a puppy.

- **Focus**: click **▶ Start focus**. Every tab that isn't a focus site closes. Until you reach your focus goal, only focus sites open; anything else is sent back to the puppy.
- **Focus sites** (you can add more in Settings): anything ending in `mit.edu`, MIT's YouTube channels (`@mit`, `@mitocw`) and their videos, ChatGPT, Claude, Gemini, and library/book sites (Google Books, Open Library, Internet Archive, Project Gutenberg, Libby/OverDrive, O'Reilly).
- **Focus goal reached**: there's no automatic break. The clock keeps going as **+00:01, +00:02…** and the puppy keeps earning treats: 1 treat for reaching the goal, plus 1 bonus treat for every 5 minutes of extra focus.
- **Break**: starts only when the goal is reached **and** you open a non-focus site (or click **Take a break**). The puppy gets its treats and plays with its ball.
- **Break is over**: the puppy scratches the door and the clock goes negative (−00:01…). A small puppy window stays on top of every web page until you click **🐾 End the fun — let puppy out**. Non-focus tabs close and the next focus starts, with the extra break time added to the goal (25:00 focus + 1:36 late = 26:36).

The toolbar icon next to the address bar shows the time: green `24m` left, gold `+3m` extra focus, blue `4m` of break, red `-2m` over the break, `||` paused.

Every treat goes into **Puppy's treats** jar in the popup: 🦴 🍖 🧀 🥕 🍪 🍗 🥩.

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
5. Click **Always Allow on Every Website** for Puppy Pomodoro. This lets it see which site is open, close distraction tabs and show the puppy window on pages. Without it, the clock still works but it can't do those.

Quick way without Xcode: Safari Settings → **Developer** → **Add Temporary Extension…** → pick the `puppy-pomodoro` folder. It's removed when you quit Safari.
6. Click the paw icon in the toolbar. Use **⤢** to open the puppy in its own tab.

For iPhone/iPad as well, leave out `--macos-only`.

## Settings

Open **Settings** at the bottom of the popup:

- How many minutes of extra focus earn a bonus treat (default 5)
- Scratching sound
- Focus sites, one per line. `mit.edu` also covers `ocw.mit.edu` etc. `youtube.com/@channel` allows that channel's pages and its videos. Add e.g. `google.com` if you want Google search while focusing.
- Empty treat jar

## Files

| File | What it does |
|---|---|
| `manifest.json` | Extension setup (Manifest V3) |
| `background.js` | The timer, focus-site rules, closing/blocking distraction tabs, treats, badge |
| `content.js` | Runs on web pages: reports the page (and YouTube channel), shows the puppy window when the break is over, and short messages |
| `app.html` / `app.css` / `app.js` | The popup and puppy tab: clock, room with puppy and door, treat jar, settings |

It also runs in Chrome: `chrome://extensions` → Developer mode → **Load unpacked** → pick this folder.
