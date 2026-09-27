// popup.js — VideoIQ Danmu
const STORAGE_KEY = 'videoiq_danmu';
const TITLES_KEY  = 'videoiq_titles';
let myName = 'Me';

// ── TAB SWITCHING ────────────────────────────────────────────────────────────
document.querySelectorAll('.tab').forEach(tab => {
  tab.onclick = () => {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
    tab.classList.add('active');
    document.getElementById('panel-' + tab.dataset.tab).classList.add('active');
  };
});

// ── BADGE: are we on YouTube? ────────────────────────────────────────────────
chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
  const url = tabs[0]?.url || '';
  const badge = document.getElementById('ytBadge');
  if (url.includes('youtube.com/watch')) {
    badge.textContent = '▶ Active';
    badge.classList.add('active');
  } else {
    badge.textContent = 'Not on YouTube';
  }
});

// ── LOAD & RENDER HISTORY ────────────────────────────────────────────────────
function loadHistory() {
  chrome.storage.local.get([STORAGE_KEY, TITLES_KEY, 'videoiq_settings'], (res) => {
    const data     = res[STORAGE_KEY] || {};
    const titles   = res[TITLES_KEY]  || {};
    const sett     = res['videoiq_settings'] || {};
    myName = sett.username || 'Me';

    const videoIds = Object.keys(data);
    const noteCount = videoIds.reduce((s, id) => s + (data[id]?.length || 0), 0);

    document.getElementById('totalNotes').textContent  = noteCount;
    document.getElementById('totalVideos').textContent = videoIds.length;

    const list = document.getElementById('historyList');

    if (videoIds.length === 0) {
      list.innerHTML = `<div class="empty-state"><div class="big">📭</div>No notes yet.<br>Open a YouTube video and start writing!</div>`;
      return;
    }

    // Sort videos: most recently annotated first (highest note id = most recent)
    const sorted = videoIds.slice().sort((a, b) => {
      const latestA = Math.max(...(data[a].map(n => n.id || 0)));
      const latestB = Math.max(...(data[b].map(n => n.id || 0)));
      return latestB - latestA;
    });

    list.innerHTML = sorted.map((videoId, idx) => {
      const notes = (data[videoId] || []).slice().sort((a, b) => a.time - b.time);
      const title = titles[videoId] || `YouTube Video`;
      const thumb = `https://i.ytimg.com/vi/${videoId}/default.jpg`;
      const noteWord = notes.length === 1 ? 'note' : 'notes';

      // Format last-edited date
      const lastId = Math.max(...notes.map(n => n.id || 0));
      const lastDate = lastId ? new Date(lastId).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) : '';

      const notesHtml = notes.map(note => {
        const isSummary = note.isSummary;
        const isOwn     = note.user === myName;
        const isOther   = !isOwn;
        const borderCls = isOther ? 'style="border-left-color:#2dd4bf"' : '';
        return `
        <div class="note-item" data-videoid="${videoId}" data-time="${note.time}" ${borderCls}>
          <span class="note-time">${isSummary ? '📋' : (note.ts || fmtTime(note.time))}</span>
          <span class="note-user" style="color:${note.color || '#4f9eff'}">${escHtml(note.user || 'Me')}</span>
          ${isSummary ? '<span class="note-summary-tag">Summary</span>' : ''}
          <span class="note-text">${escHtml(note.text)}</span>
        </div>
      `}).join('');

      // Open the first video by default
      const openClass = idx === 0 ? 'open' : '';

      return `
        <div class="video-card ${openClass}" data-videoid="${videoId}">
          <div class="video-header">
            <div class="video-thumb">
              <img src="${thumb}" alt="" onerror="this.style.display='none';this.parentNode.textContent='▶'">
            </div>
            <div class="video-info">
              <div class="video-title">${escHtml(title)}</div>
              <div class="video-meta">${notes.length} ${noteWord}${lastDate ? ' · ' + lastDate : ''}</div>
            </div>
            <button class="export-video-btn" data-videoid="${videoId}" data-title="${escHtml(title)}" title="Export this video's notes">⬇</button>
            <div class="video-chevron">▼</div>
          </div>
          <div class="notes-list">${notesHtml}</div>
        </div>
      `;
    }).join('');

    // Toggle cards open/closed
    list.querySelectorAll('.video-header').forEach(header => {
      header.onclick = (e) => {
        if (e.target.classList.contains('export-video-btn')) return;
        header.closest('.video-card').classList.toggle('open');
      };
    });

    // Per-video export — only exports the current user's own notes, not imported ones
    list.querySelectorAll('.export-video-btn').forEach(btn => {
      btn.onclick = (e) => {
        e.stopPropagation();
        const vid        = btn.dataset.videoid;
        const myNotes    = (data[vid] || []).filter(n => n.user === myName);
        const videoTitle = btn.dataset.title;
        const slug       = videoTitle.replace(/[^a-z0-9]/gi,'_').slice(0,40);
        if (!myNotes.length) { alert('No notes of yours to export for this video.'); return; }
        const payload    = {
          _meta: {
            author:     myName,
            exportedAt: new Date().toISOString(),
            videoTitle: videoTitle,
            videoId:    vid
          },
          [vid]: myNotes
        };
        const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
        const url  = URL.createObjectURL(blob);
        const a    = document.createElement('a');
        a.href = url; a.download = `videoiq_${myName}_${slug}.json`; a.click();
        URL.revokeObjectURL(url);
      };
    });

    // Click a note → open YouTube at that timestamp
    list.querySelectorAll('.note-item').forEach(item => {
      item.onclick = () => {
        const vid  = item.dataset.videoid;
        const time = parseInt(item.dataset.time, 10) || 0;
        const url  = `https://www.youtube.com/watch?v=${vid}&t=${time}s`;

        // Try to reuse an existing YouTube tab for this video
        chrome.tabs.query({}, (tabs) => {
          const existing = tabs.find(t => t.url && t.url.includes(`v=${vid}`));
          if (existing) {
            chrome.tabs.update(existing.id, { active: true, url });
            chrome.windows.update(existing.windowId, { focused: true });
          } else {
            chrome.tabs.create({ url });
          }
          window.close();
        });
      };
    });

    // Fetch missing titles from YouTube oEmbed (best-effort, no API key needed)
    fetchMissingTitles(sorted, titles, data);
  });
}

// ── FETCH VIDEO TITLES ────────────────────────────────────────────────────────
function fetchMissingTitles(videoIds, titles, data) {
  const missing = videoIds.filter(id => !titles[id]);
  if (missing.length === 0) return;

  let updated = false;
  missing.forEach(id => {
    fetch(`https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${id}&format=json`)
      .then(r => r.json())
      .then(info => {
        if (info.title) {
          titles[id] = info.title;
          updated = true;
          // update the card title in the DOM immediately
          const card = document.querySelector(`.video-card[data-videoid="${id}"]`);
          if (card) {
            const titleEl = card.querySelector('.video-title');
            if (titleEl) titleEl.textContent = info.title;
          }
          chrome.storage.local.set({ [TITLES_KEY]: titles });
        }
      })
      .catch(() => {});  // silent fail — no title cached, shows fallback
  });
}

// ── HELPERS ──────────────────────────────────────────────────────────────────
function fmtTime(secs) {
  const s = Math.floor(secs || 0);
  const m = Math.floor(s / 60);
  const ss = (s % 60).toString().padStart(2, '0');
  return `${m}:${ss}`;
}

function escHtml(s) {
  return String(s)
    .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

// Local sync bookkeeping must not travel inside exported / imported files
function stripSync(n) {
  const o = {};
  for (const k in n) if (!['_synced','_syncedAt','_dirty','_rev'].includes(k)) o[k] = n[k];
  return o;
}

// ── EXPORT ───────────────────────────────────────────────────────────────────
document.getElementById('exportBtn').onclick = () => {
  chrome.storage.local.get([STORAGE_KEY, 'videoiq_settings'], (res) => {
    const data   = res[STORAGE_KEY] || {};
    const name   = res['videoiq_settings']?.username || myName;
    // Only export notes written by the current user
    const mine = {};
    for (const vid in data) {
      const myNotes = data[vid].filter(n => n.user === name).map(stripSync);
      if (myNotes.length) mine[vid] = myNotes;
    }
    const payload = { _meta: { author: name, exportedAt: new Date().toISOString() }, ...mine };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement('a');
    a.href = url;
    a.download = `videoiq_${name}_all-videos.json`;
    a.click();
    URL.revokeObjectURL(url);
    showStatus('Exported ✓');
  });
};

// ── IMPORT ───────────────────────────────────────────────────────────────────
document.getElementById('importBtn').onclick = () =>
  document.getElementById('fileInput').click();

document.getElementById('fileInput').onchange = (e) => {
  const file = e.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = (ev) => {
    try {
      const incoming = JSON.parse(ev.target.result);
      chrome.storage.local.get([STORAGE_KEY], (res) => {
        const existing = res[STORAGE_KEY] || {};
        let added = 0;
        for (const vid in incoming) {
          if (vid === '_meta' || !Array.isArray(incoming[vid])) continue;
          if (!existing[vid]) existing[vid] = [];
          const ids = new Set(existing[vid].map(d => d.id));
          for (const entry of incoming[vid]) {
            if (!ids.has(entry.id)) { existing[vid].push(stripSync(entry)); added++; }
          }
        }
        chrome.storage.local.set({ [STORAGE_KEY]: existing }, () => {
          showStatus(`✓ Merged ${added} new note${added !== 1 ? 's' : ''}`);
          e.target.value = '';
          loadHistory();
        });
      });
    } catch { showStatus('❌ Invalid JSON file'); }
  };
  reader.readAsText(file);
};

// ── CLEAR ────────────────────────────────────────────────────────────────────
document.getElementById('clearBtn').onclick = () => {
  if (!confirm('Delete ALL your VideoIQ notes? This cannot be undone.')) return;
  chrome.storage.local.remove([STORAGE_KEY, TITLES_KEY], () => {
    loadHistory();
    showStatus('All notes cleared.');
  });
};

function showStatus(msg) {
  const el = document.getElementById('status');
  el.textContent = msg;
  setTimeout(() => el.textContent = '', 3000);
}

// ── INIT ─────────────────────────────────────────────────────────────────────
loadHistory();
