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

All notes are stored **locally in your browser** (`chrome.storage.local`). Nothing is sent to any server. Sharing only happens when you manually export/import JSON files.

---

## Files

```
videoiq-extension/
├── manifest.json    — Extension config
├── content.js       — Main logic injected into YouTube
├── danmu.css        — Styles for overlay and panel
├── popup.html       — Extension popup UI
├── popup.js         — Popup logic (stats, export, import)
└── icons/
    └── icon48.png   — Extension icon
```
