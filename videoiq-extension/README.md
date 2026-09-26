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

## GitHub Sync (everyone's danmu in one shared repo)

All danmu are saved in **one repo** owned by one person. Inside it, **each person has their own file**, named after the name they chose, so nobody overwrites anyone else:

```
danmu/<youtubeVideoId>/<name>.json     e.g. danmu/dQw4w9WgXcQ/Lin.json
                                              danmu/dQw4w9WgXcQ/Friend.json
```

Only the repo owner needs a GitHub account. Friends don't need GitHub at all.

### One-time setup (repo owner)
1. On github.com: **+** → **New repository** → name it e.g. `danmu-data` (private is fine) → tick *Add a README* → Create.
2. Make **one token for that repo only**: your picture → **Settings** → **Developer settings** → **Personal access tokens** →
   **Fine-grained tokens** → **Generate new token**
   - Repository access: **Only select repositories** → `danmu-data`
   - Permissions → Repository permissions → **Contents: Read and write**
   - Generate, then copy the token (starts with `github_pat_`)
3. Send your friend the repo name (`yourGitHubName/danmu-data`) and the token privately.
   The token can only touch that one repo.

### Each person
1. In the extension panel click **⚙**, type **your own name** in *Your name* (it must be different from your friend's).
2. Under **🐙 GitHub sync** enter the same `owner/danmu-data` and the same token → **Connect**.
   You'll see "Saving as <your name>". To change your name later, Disconnect first.

### Using it
- Every note you add, edit or delete is saved to **your** file in the shared repo about 2 seconds later ("🐙 Saved to GitHub").
- The other person's danmu (marked 🐙) load when you open a video and refresh **every 15 seconds** while the tab is visible. They float on the video at their timestamps, with their chosen style.
- **↩ Reply** on someone's note jumps to that moment and starts a `@theirname ` danmu. Notes that @mention you are highlighted in gold.
- The 👥 selector lets you hide a person's danmu on the video or shift their timing. That only affects your screen.
- **⟳ Sync now** in ⚙ forces a save and reload. Opening the same video on a new computer restores your own notes from GitHub.
- The token is stored only in this browser (`chrome.storage.local`), separately from settings, and is never included in exports.

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

All notes are stored **locally in your browser** (`chrome.storage.local`). Nothing leaves your browser unless you turn on **GitHub sync** (your notes go to the repo you chose) or **Post publicly**, or export a JSON file yourself.

---

## Files

```
videoiq-extension/
├── manifest.json    — Extension config
├── content.js       — Main logic injected into YouTube
├── github.js        — GitHub sync (one file per person per video)
├── danmu.css        — Styles for overlay and panel
├── popup.html       — Extension popup UI
├── popup.js         — Popup logic (stats, export, import)
└── icons/
    └── icon48.png   — Extension icon
```
