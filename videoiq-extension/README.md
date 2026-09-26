# VideoIQ Danmu — Chrome Extension

Add personal floating comments (danmu) to any YouTube video. Compare your notes with your teacher or classmates.

---

## Install (unpacked, no store needed)

1. Open Chrome and go to `chrome://extensions`
2. Enable **Developer Mode** (toggle top-right)
3. Click **Load unpacked**
4. Select this folder (`videoiq-extension`)
5. Open any YouTube video — the VideoIQ panel appears on the right!

---

## How to Use

### Writing Danmu
- **On video**: Hover over the video → a text bar appears at the bottom. Type + press Enter (or click Send).  
  Your note floats across the screen like classic danmu, tied to that exact timestamp.
- **Side panel**: Type in the box at the bottom of the VideoIQ panel (right side of the page). Notes appear in the list immediately.

### Danmu Style (font, color, size, position, emoji)
Under the note box in the panel there is a style bar:

| Control | Options |
|---|---|
| Font | Default, Arial, Serif, Mono, Comic, Impact, 黑体 Hei, 楷体 Kai |
| Size | Small / Medium / Large / Huge |
| Color | Any color (color picker) |
| Position | ⬅ Scroll right → left · ➡ Scroll left → right · ⬆ Stay on top · ⬇ Stay on bottom |
| Duration | For top/bottom danmu: how many seconds it stays (2–15s) |
| 😊 | Emotion emoji picker — inserts at the cursor (also in the minimized bar) |

- **▶ Preview** shows a sample danmu on the video with the current style.
- Your style is **saved automatically** and used for every new danmu until you change it again (it survives page reloads and new videos).
- Each note remembers the style it was written with; public posts carry their style too.

### Viewing & Comparing
- The side panel lists all notes sorted by timestamp
- **Click any note** → video jumps to that moment
- Notes **highlight in gold** as the video reaches their timestamp
- Use the **All / Mine / Followed** filter buttons to switch views

### Following Your Teacher
1. Click ⚙ in the VideoIQ panel header
2. Enter your teacher's username in the **Follow** field
3. Your teacher exports their notes (from the extension popup) and shares the JSON file with you
4. You click the extension icon → **Import / Merge Notes** → paste the JSON
5. Now their notes appear in your panel with a purple left border — compare side by side!

### Settings (⚙ in the panel)
| Setting | What it does |
|---|---|
| Your name | How your danmu appears to others |
| Your color | Color of your floating danmu & name |
| Follow | Username whose imported notes you want to see |
| Show my notes | Toggle your own danmu on/off |
| Show followed | Toggle followed user's danmu on/off |
| Float on video | Toggle whether danmu floats across the video |

---

## Accounts & Online Saving (everyone's danmu in one place)

All danmu from all users are saved in **one online database** (Supabase).
The extension owner sets it up once (see **SETUP.md**). Everyone else just installs the extension and signs in.

### For users
1. Click **👤 Sign in** in the panel header.
2. First time: **Create account** → display name (unique; everyone sees it), email, password.
   Depending on the setup, you may need to click the confirmation link in your email first, then **Sign in**.
3. That's it. Every danmu you add, edit or delete is saved online automatically ("☁ Saved online").
   Notes you wrote before signing in are uploaded too.

### What you get
- **Everyone's danmu** on the video you're watching (☁ in the list), refreshed every 10 seconds.
  They float at their timestamps in each author's style.
- **Your danmu are protected:** only you can edit or delete them (enforced by the database).
- **Any computer:** sign in and your danmu come back. Edits and deletes sync across devices.
- **↩ Reply** on someone's danmu jumps there and starts `@theirname `. Danmu that @mention you are highlighted in gold.
- Change your **name or color** in ⚙ → Save. Everyone sees the new name on all your danmu.
- The 👥 selector hides a person's danmu on the video or shifts their timing (only on your screen).
- You can watch everyone's danmu without signing in. Signing in is needed to save your own online.
- Offline or signed out? Notes stay in your browser and upload when you're back and signed in.

---

## Sharing Notes

**Student → Teacher:**
1. Click the 📝 extension icon in Chrome toolbar
2. Click **Export My Notes** → saves a `.json` file
3. Send it to your teacher

**Teacher → Students:**
Same export. Students import via the popup's **Import / Merge Notes** button.

Notes are merged non-destructively — you keep yours, you add theirs.

---

## Privacy

All notes are stored **locally in your browser** (`chrome.storage.local`). Nothing leaves your browser until you **sign in**: then your danmu (and your display name/color) are saved to the online database, where anyone using the extension can read them. Your email is only used for your account. Passwords are handled by Supabase and never stored by the extension.

---

## Files

```
videoiq-extension/
├── manifest.json    — Extension config
├── content.js       — Main logic injected into YouTube
├── cloud.js         — Accounts + online database (Supabase)
├── config.js        — Your Supabase project URL + public key
├── SETUP.md         — One-time database setup for the owner
├── danmu.css        — Styles for overlay and panel
├── popup.html       — Extension popup UI
├── popup.js         — Popup logic (stats, export, import)
└── icons/
    └── icon48.png   — Extension icon
```
