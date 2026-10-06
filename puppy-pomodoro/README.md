# 🐾 Puppy Pomodoro — Safari extension

A focus clock with Pork, a fluffy white dog with gray ears and a navy harness.

- **Focus**: click **▶ Start focus**. Every tab that isn't a focus site closes. Until you reach your focus goal, only focus sites open; anything else is sent back to Pork.
- **Focus sites** (you can add more in Settings): anything ending in `mit.edu`, MIT's YouTube channels (`@mit`, `@mitocw`) and their videos, ChatGPT, Claude, Gemini, Google (search, Gmail, Drive, Docs, Calendar, Tasks and every other google.com page), Notion, Outlook and Word on the web (Microsoft 365, OneDrive, SharePoint), Kindle (read.amazon.com), the danmu site (sssamui.github.io/morethanaproject/danmu — its YouTube videos play inside the page, so they work during focus), and library/book sites (Google Books, Open Library, Internet Archive, Project Gutenberg, Libby/OverDrive, O'Reilly). The Outlook, Word and Kindle Mac apps are never blocked; the extension only works inside Safari.
- **Treats**: next to the clock, Pork's next treat shows with **"Pork will get a treat after 12:34"**. He gets it right when you reach the focus goal (25 min), and a bonus treat for every 5 minutes of extra focus after that. Each one goes straight into the treat jar, with a message on the page.
- **Focus goal reached**: there's no automatic break and no reminder to take one. Focus can go on as long as you like: the clock keeps going as **+00:01 … +3:01:00** and the next bonus treat counts down next to it. Focus goals can be up to 720 minutes.
- **Break**: starts only when the goal is reached **and** you open a non-focus site (or click **Take a break**). Pork **sits by the glass door, waiting** for the whole break.
- **Break is over**: the clock goes negative (−00:01…). For the first 2 minutes Pork **paces back and forth** ("Can we go out? 🥺"); after that he **stands up and scratches the door** ("Woof! Let me out!"). A small window with Pork stays on top of every web page until you click **🐾 End the fun — let Pork out**. Non-focus tabs close and the next focus starts, with the extra break time added to the goal (25:00 focus + 1:36 late = 26:36).

- **Night mode**: from 12:00 AM to 6:00 AM only focus sites can open, whatever the clock is doing (stopped, paused, break, or extra focus). At 12:00 AM every non-focus tab closes, and opening one shows Pork's page with "🌙 Night mode: only focus sites can open now". Opening a non-focus site doesn't start a break at night. The end time isn't shown anywhere unless you look for it: click **🌙 Night mode** near the bottom of the popup to see or change the hours, then press its **Save** button.
- **Back to normal after a custom session**: a focus shorter than 25 minutes or a break longer than 5 minutes only counts for that one session. When the next focus starts by itself (after letting Pork out, or the automatic start), focus goes back to at least 25 minutes and the break to at most 5. Longer focus and shorter breaks are kept.
- **Pork's tab is always open**: Pork's page stays open as a pinned tab, first in the window. If you close it, it opens again. (Settings → "Keep Pork's page open as a tab" turns this off.)
- **Starts by itself**: focus starts without a click when Safari opens or the Mac wakes up from sleep. If you pause or stop, it starts again by itself after 30 minutes (a paused clock resumes; a stopped clock starts a new focus). The popup shows when: "🐶 Focus starts by itself at 3:45 PM".

The toolbar icon next to the address bar shows the time: green `24m` left, gold `+3m` extra focus (hours from 1 hour on: `+2h`), blue `4m` of break, red `-2m` over the break, `||` paused.

Every treat goes into **Pork's treats** jar in the popup: 🦴 🍖 🧀 🥕 🍪 🍗 🥩.

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
5. Safari never turns these on by itself, for any extension. Pork's page shows a button for the first one and the steps for the second:
   - **Allow on every website**: click the button on Pork's page and choose **Always Allow on Every Website**.
   - **Private windows**: Safari Settings → **Extensions** → **Puppy Pomodoro** → check **Allow in Private Browsing**.

   Website access lets it see which site is open, close distraction tabs and show Pork's window on pages. Without it, the clock still works but it can't do those.
6. Click the paw icon in the toolbar. Use **⤢** to open the puppy in its own tab.

For iPhone/iPad as well, leave out `--macos-only`.

Quick way without Xcode: Safari Settings → **Developer** → **Add Temporary Extension…** → pick the `puppy-pomodoro` folder. It's removed when you quit Safari, so "start when Safari opens" only works with the Xcode version.

To have Safari (and Pork) start when you log in to your Mac: System Settings → **General** → **Login Items** → **+** → choose **Safari**.

## Settings

Open **Settings** at the bottom of the popup:

- How many minutes of extra focus earn a bonus treat (default 5)
- Scratching sound
- Start focus by itself when Safari opens or the Mac wakes up (on by default)
- After pausing or stopping, start again by itself after N minutes (default 30, 0 = never)
- Keep Pork's page open as a tab (on by default)
- Focus sites, one per line. `mit.edu` also covers `ocw.mit.edu` etc. `youtube.com/@channel` allows that channel's pages and its videos. Remove `google.com` if you only want some Google services: keep e.g. `mail.google.com` and `drive.google.com`.
- Empty treat jar

## Files

| File | What it does |
|---|---|
| `manifest.json` | Extension setup (Manifest V3) |
| `background.js` | The timer, focus-site rules, closing/blocking distraction tabs, treats, badge |
| `pork.js` | The drawing of Pork and his poses (napping, waiting, pacing, scratching), shared by the popup and the on-page window |
| `content.js` | Runs on web pages: reports the page (and YouTube channel), shows Pork's window when the break is over, and short messages |
| `app.html` / `app.css` / `app.js` | The popup and puppy tab: clock, room with Pork and the glass door, treat jar, settings |

It also runs in Chrome: `chrome://extensions` → Developer mode → **Load unpacked** → pick this folder.
