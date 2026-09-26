// VideoIQ Danmu — content.js  v9
// Local-first. No account needed. Optionally post publicly with a name.
(function () {
  'use strict';

  const LOCAL_KEY    = 'videoiq_danmu';
  const SETTINGS_KEY = 'videoiq_settings';

  let settings = {
    username: 'Me', color: '#4f9eff',
    showOwn: true, showOnVideo: true,
    panelX: null, panelY: null, minimized: false,
    defaultPublic: true,
    // Danmu style — remembered until the user changes it again
    danmuStyle: null
  };

  // ── DANMU STYLE OPTIONS ──────────────────────────────────────────────────────
  const EMOJI_FALLBACK = '"Segoe UI Emoji","Apple Color Emoji","Noto Color Emoji",sans-serif';
  const FONTS = [
    { id: 'default', label: 'Default',   css: "'Segoe UI',system-ui" },
    { id: 'arial',   label: 'Arial',     css: 'Arial,Helvetica' },
    { id: 'serif',   label: 'Serif',     css: 'Georgia,"Times New Roman",serif' },
    { id: 'mono',    label: 'Mono',      css: '"Courier New",Consolas,monospace' },
    { id: 'comic',   label: 'Comic',     css: '"Comic Sans MS","Comic Neue",cursive' },
    { id: 'impact',  label: 'Impact',    css: 'Impact,"Arial Black"' },
    { id: 'hei',     label: '黑体 Hei',   css: '"Microsoft YaHei","PingFang SC","Noto Sans SC",SimHei' },
    { id: 'kai',     label: '楷体 Kai',   css: 'KaiTi,STKaiti,"Kaiti SC",serif' }
  ];
  const SIZES = [
    { id: 's',  label: 'Small',  px: 14 },
    { id: 'm',  label: 'Medium', px: 18 },
    { id: 'l',  label: 'Large',  px: 24 },
    { id: 'xl', label: 'Huge',   px: 32 }
  ];
  const MODES = [
    { id: 'rtl',    label: '⬅ Scroll right → left' },
    { id: 'ltr',    label: '➡ Scroll left → right' },
    { id: 'top',    label: '⬆ Stay on top' },
    { id: 'bottom', label: '⬇ Stay on bottom' }
  ];
  const DURATIONS = [2, 3, 5, 8, 10, 15];
  const EMOJIS = [
    ['😀','happy'],['😂','laughing'],['🤣','rofl'],['😊','smile'],['😍','love'],['🥰','adore'],
    ['😎','cool'],['🤩','amazed'],['😮','surprised'],['😱','shocked'],['🤯','mind blown'],['🤔','thinking'],
    ['😐','neutral'],['🙄','eye roll'],['😴','sleepy'],['😢','sad'],['😭','crying'],['😡','angry'],
    ['😤','frustrated'],['😨','scared'],['😳','embarrassed'],['🥺','pleading'],['😅','relieved'],['🤗','hug'],
    ['👍','like'],['👎','dislike'],['👏','applause'],['🙏','thanks'],['❤️','heart'],['💔','heartbroken'],
    ['🔥','fire'],['💯','perfect'],['🎉','celebrate'],['✨','sparkle'],['❓','question'],['❗','important']
  ];
  const DEFAULT_STYLE = { font: 'default', size: 'm', color: null, mode: 'rtl', duration: 5 };

  // Current style for new danmu (color falls back to the user's color)
  function curStyle() {
    const st = Object.assign({}, DEFAULT_STYLE, settings.danmuStyle || {});
    if (!st.color) st.color = settings.color;
    return st;
  }

  let localNotes  = {};    // { videoId: [note…] } — saved locally
  let publicPosts = [];    // posts loaded from cloud for this video
  let allDanmu    = [];    // ALL notes merged, sorted by adjusted time — used by sidebar
  let activeDanmu = [];    // only notes the user wants ON VIDEO (checked in selector)

  // Per-user display offset (seconds): { authorName: offsetSeconds }
  // Positive = show their danmu later; negative = earlier
  let userOffsets  = {};   // { authorName: number }
  let visibleUsers = null; // Set of authorNames to show ON VIDEO; null = show all

  let videoId   = null;
  let isShorts  = false;
  let videoEl   = null;
  let danmuContainer = null;
  let sidePanel = null;
  let lastTime  = -1;
  let animFrame = null;
  let editingId = null;
  let pausedForNote = false;
  let summaryMode   = false;

  // Cloud post authors for this video: [{id, author_name, color, notes, posted_at}]
  let cloudAuthors = [];

  // ── BOOT ─────────────────────────────────────────────────────────────────────
  function boot() {
    chrome.storage.local.get([LOCAL_KEY, SETTINGS_KEY], (res) => {
      localNotes = res[LOCAL_KEY] || {};
      settings   = Object.assign(settings, res[SETTINGS_KEY] || {});
      waitForVideo();
    });
  }

  function save() {
    chrome.storage.local.set({ [LOCAL_KEY]: localNotes, [SETTINGS_KEY]: settings });
  }

  function saveVideoTitle(title) {
    if (!title || !videoId) return;
    chrome.storage.local.get(['videoiq_titles'], (res) => {
      const titles = res['videoiq_titles'] || {};
      if (titles[videoId] === title) return;
      titles[videoId] = title;
      chrome.storage.local.set({ videoiq_titles: titles });
    });
  }

  // ── VIDEO ID ─────────────────────────────────────────────────────────────────
  function getVideoId() {
    const path = location.pathname;
    if (path.startsWith('/shorts/')) {
      isShorts = true;
      return path.replace('/shorts/', '').split(/[/?#]/)[0] || null;
    }
    isShorts = false;
    return new URLSearchParams(location.search).get('v') || null;
  }

  // ── WAIT FOR VIDEO ───────────────────────────────────────────────────────────
  function waitForVideo() {
    let n = 0;
    const t = setInterval(() => {
      n++;
      videoEl = document.querySelector('video');
      const id = getVideoId();
      if (videoEl && id) {
        clearInterval(t);
        videoId = id;
        rebuildActive();
        if (!sidePanel) buildUI();
        startLoop();
        watchNavigation();
        loadCloudPosts();
      }
      if (n > 50) clearInterval(t);
    }, 600);
  }

  // ── CLOUD LOAD ───────────────────────────────────────────────────────────────
  async function loadCloudPosts() {
    if (!window.VIQ_CLOUD?.isConfigured()) return;
    setCloudBar('loading', '☁ Loading public notes…');
    try {
      const posts = await VIQ_CLOUD.getPostsForVideo(videoId);
      cloudAuthors = posts || [];
      rebuildActive();
      refreshSideList();
      buildUserSelector();
      if (cloudAuthors.length === 0) {
        setCloudBar('empty', '☁ No public notes for this video yet. Be the first — click <b>🌐 Post publicly</b>!');
      } else {
        const total = cloudAuthors.reduce((s,p)=>s+(p.notes||[]).length,0);
        const names = cloudAuthors.map(p=>'<span style="color:'+p.color+'">'+escH(p.author_name)+'</span>').join(', ');
        setCloudBar('loaded', '👥 ' + total + ' public note' + (total!==1?'s':'') + ' from: ' + names);
        setTimeout(() => setCloudBar('hidden', ''), 5000);
      }
    } catch (e) {
      setCloudBar('error', '⚠ Could not load public notes');
      console.warn('VideoIQ cloud load:', e.message);
    }
  }

  function setCloudBar(state, html) {
    const bar = document.getElementById('viq-cloud-bar'); if (!bar) return;
    bar.className = 'viq-cloud-bar viq-cloud-' + state;
    bar.innerHTML = html;
    bar.classList.toggle('hidden', state === 'hidden');
  }

  // ── MERGE LOCAL + CLOUD ──────────────────────────────────────────────────────
  // allDanmu   = every note from everyone, sorted by adjusted time → used by sidebar
  // activeDanmu = only notes checked for VIDEO overlay → used by floating danmu
  function rebuildActive() {
    const mine = (localNotes[videoId] || []).slice();

    // Flatten cloud posts into note objects, applying per-user offset
    const cloudNotes = [];
    cloudAuthors.forEach(post => {
      const off = userOffsets[post.author_name] || 0;
      (post.notes || []).forEach(n => {
        const adjustedTime = Math.max(0, (n.time || 0) + off);
        cloudNotes.push({
          id:        'c_' + post.id + '_' + n.time + '_' + Math.random(),
          user:      post.author_name,
          color:     post.color,
          text:      n.text,
          time:      adjustedTime,
          ts:        fmtTime(adjustedTime),
          isSummary: n.isSummary || false,
          style:     n.style || null,
          _cloud:    true,
          _postId:   post.id,
          _offset:   off || undefined
        });
      });
    });

    // allDanmu: everyone, sorted by adjusted time — always shown in sidebar
    allDanmu = [...mine, ...cloudNotes].sort((a, b) => a.time - b.time);

    // activeDanmu: only users checked for video overlay
    if (visibleUsers === null) {
      // All checked → same as allDanmu
      activeDanmu = allDanmu;
    } else {
      activeDanmu = allDanmu.filter(n =>
        n.user === settings.username ||  // own notes always on video
        visibleUsers.has(n.user)
      );
    }
  }

  // ── NAVIGATION ───────────────────────────────────────────────────────────────
  function watchNavigation() {
    let lastUrl = location.href;
    new MutationObserver(() => {
      if (location.href === lastUrl) return;
      lastUrl = location.href;
      setTimeout(() => {
        const newId = getVideoId();
        if (!newId || newId === videoId) return;
        videoId = newId;
        videoEl = document.querySelector('video');
        cloudAuthors = []; visibleUsers = null; userOffsets = {};
        activeDanmu = [];
        editingId = null; pausedForNote = false; summaryMode = false;
        const onReady = () => {
          rebuildActive(); clearDanmuOverlay();
          refreshSideList(); buildUserSelector();
          updateShortsBadge();
          loadCloudPosts();
        };
        if (videoEl) onReady();
        else {
          const w = setInterval(() => {
            videoEl = document.querySelector('video');
            if (videoEl) { clearInterval(w); onReady(); }
          }, 400);
        }
      }, 800);
    }).observe(document, { subtree: true, childList: true });

    document.addEventListener('fullscreenchange', onFullscreenChange);
  }

  function updateShortsBadge() {
    const b = document.getElementById('viq-shorts-badge');
    if (b) b.style.display = isShorts ? 'inline' : 'none';
  }

  function onFullscreenChange() {
    const fs = document.fullscreenElement;
    if (fs) {
      if (sidePanel) fs.appendChild(sidePanel);
      clearDanmuOverlay();
      danmuContainer = document.createElement('div');
      danmuContainer.id = 'viq-danmu-overlay';
      fs.appendChild(danmuContainer);
    } else {
      if (sidePanel) document.body.appendChild(sidePanel);
      clearDanmuOverlay(); buildDanmuOverlay();
    }
  }

  // ── BUILD UI ─────────────────────────────────────────────────────────────────
  function buildUI() {
    buildDanmuOverlay();
    buildPanel();
    buildToggleButton();
  }

  function buildDanmuOverlay() {
    if (document.getElementById('viq-danmu-overlay')) return;
    const playerEl = document.querySelector('#movie_player') ||
                     document.querySelector('.html5-video-player') ||
                     videoEl?.closest('ytd-shorts') ||
                     videoEl?.parentElement;
    danmuContainer = document.createElement('div');
    danmuContainer.id = 'viq-danmu-overlay';
    (playerEl || document.body).appendChild(danmuContainer);
  }

  // ── PANEL ────────────────────────────────────────────────────────────────────
  function buildPanel() {
    if (document.getElementById('viq-side-panel')) return;
    sidePanel = document.createElement('div');
    sidePanel.id = 'viq-side-panel';
    const px = settings.panelX !== null ? settings.panelX : (window.innerWidth - 360);
    const py = settings.panelY !== null ? settings.panelY : 80;
    sidePanel.style.left = clamp(px, 0, window.innerWidth  - 340) + 'px';
    sidePanel.style.top  = clamp(py, 0, window.innerHeight - 100) + 'px';
    sidePanel.innerHTML  = panelHTML();
    document.body.appendChild(sidePanel);
    wirePanel();
    if (settings.minimized) setMinimized(true);
  }

  function panelHTML() {
    const cloudOK = window.VIQ_CLOUD?.isConfigured();
    return `
      <div class="viq-panel-header" id="viq-drag-handle">
        <span class="viq-drag-icon">⠿</span>
        <span class="viq-logo">📝 VideoIQ
          <span id="viq-shorts-badge" class="viq-shorts-badge"
            style="display:${isShorts?'inline':'none'}">Shorts</span>
        </span>
        <!-- collapsed input bar -->
        <div id="viq-mini-bar" class="viq-mini-bar hidden">
          <input id="viq-mini-input" class="viq-mini-input" placeholder="Note at ..." maxlength="200"/>
          <button id="viq-mini-emoji"   class="viq-mini-btn viq-emoji-toggle" title="Emotion emoji">😊</button>
          <button id="viq-mini-pause"   class="viq-mini-btn" title="Pause">⏸</button>
          <button id="viq-mini-summary" class="viq-mini-btn" title="Summary">📋</button>
          <button id="viq-mini-send"    class="viq-mini-btn viq-mini-send" title="Send">↵</button>
        </div>
        <div class="viq-header-actions" id="viq-header-actions">
          <button class="viq-icon-btn" id="viq-export-btn"   title="Export my notes as JSON file">⬇</button>
          <button class="viq-icon-btn" id="viq-import-btn"   title="Import someone's JSON file">⬆</button>
          ${cloudOK ? '<button class="viq-publish-pill" id="viq-publish-btn" title="Post your notes publicly so others can see them">🌐 Post publicly</button>' : ''}
          <button class="viq-icon-btn" id="viq-settings-btn" title="Settings">⚙</button>
        </div>
        <button class="viq-icon-btn" id="viq-minimize-btn" title="Minimize">–</button>
      </div>

      <!-- EMOTION EMOJI PICKER -->
      <div id="viq-emoji-picker" class="viq-emoji-picker hidden">
        ${EMOJIS.map(([e,name]) => '<button class="viq-emoji" data-emoji="'+e+'" title="'+name+'">'+e+'</button>').join('')}
      </div>

      <!-- CLOUD STATUS BAR — shown while loading or when others' notes are found -->
      <div id="viq-cloud-bar" class="viq-cloud-bar hidden"></div>

      <input type="file" id="viq-file-input" accept=".json" style="display:none"/>

      <!-- PUBLISH DIALOG -->
      <div id="viq-publish-dialog" class="viq-publish-dialog hidden">
        <div class="viq-pd-title">🌐 Post your notes publicly</div>
        <div class="viq-pd-desc">Anyone watching this video will see your danmu floating on screen and in their sidebar. No account needed — just pick a name.</div>
        <div class="viq-pd-row">
          <label>Display name</label>
          <input id="viq-pd-name"  class="viq-input" value="${escH(settings.username)}" maxlength="30" placeholder="Your name (or Anonymous)"/>
        </div>
        <div class="viq-pd-row">
          <label>Color</label>
          <input id="viq-pd-color" type="color" value="${escH(settings.color)}"/>
        </div>
        <div class="viq-pd-preview" id="viq-pd-preview"></div>
        <div class="viq-pd-btns">
          <button id="viq-pd-cancel"  class="viq-cancel-btn">Cancel</button>
          <button id="viq-pd-confirm" class="viq-add-btn">Post</button>
        </div>
        <div class="viq-pd-msg" id="viq-pd-msg"></div>
      </div>

      <!-- IMPORT OFFSET DIALOG -->
      <div id="viq-offset-dialog" class="viq-offset-dialog hidden">
        <div class="viq-offset-title" id="viq-offset-title">⏱ Time Offset for Import</div>
        <div class="viq-offset-desc">Shift timestamps before merging. Negative = earlier (hints). Positive = later (answers).</div>
        <div id="viq-offset-rows" class="viq-offset-rows"></div>
        <div class="viq-offset-btns">
          <button id="viq-offset-cancel"  class="viq-cancel-btn">Cancel</button>
          <button id="viq-offset-confirm" class="viq-add-btn">Merge</button>
        </div>
      </div>

      <div id="viq-panel-body">
        <!-- SETTINGS -->
        <div id="viq-settings-panel" class="viq-settings hidden">
          <div class="viq-setting-row">
            <label>Your name</label>
            <input id="viq-username" class="viq-input" value="${escH(settings.username)}" maxlength="30"/>
          </div>
          <div class="viq-setting-row">
            <label>Your color</label>
            <input id="viq-color" type="color" value="${escH(settings.color)}"/>
          </div>
          <div class="viq-setting-row">
            <label><input type="checkbox" id="viq-toggle-own"   ${settings.showOwn?'checked':''}/>  Show my notes on video</label>
          </div>
          <div class="viq-setting-row">
            <label><input type="checkbox" id="viq-toggle-video" ${settings.showOnVideo?'checked':''}/> Float danmu on video</label>
          </div>
          <div id="viq-author-colors" class="viq-author-colors"></div>
          <button class="viq-btn-save" id="viq-save-settings">Save</button>
        </div>

        <!-- USER SELECTOR — one row per cloud author -->
        <div id="viq-user-selector" class="viq-user-selector hidden"></div>

        <div class="viq-filter-bar">
          <button class="viq-filter active" data-filter="all">All</button>
          <button class="viq-filter"        data-filter="mine">Mine</button>
          <button class="viq-filter"        data-filter="others">Others</button>
          <button class="viq-filter"        data-filter="compare">Compare</button>
        </div>

        <div id="viq-danmu-list" class="viq-list"></div>

        <div class="viq-add-section">
          <div class="viq-add-top">
            <span class="viq-add-label" id="viq-add-label">✍️ Add note</span>
            <div class="viq-add-controls">
              <button class="viq-pause-btn"   id="viq-pause-btn">⏸ Pause</button>
              <button class="viq-summary-btn" id="viq-summary-btn">📋 Summary</button>
            </div>
          </div>
          <div class="viq-add-row">
            <textarea id="viq-quick-input" class="viq-input viq-main-input"
              placeholder="Type here… Enter to send, Shift+Enter for new line"
              rows="2" maxlength="500"></textarea>
            <div class="viq-btn-col">
              <button id="viq-quick-add"   class="viq-add-btn">Send</button>
              <button id="viq-cancel-edit" class="viq-cancel-btn hidden">✕</button>
            </div>
          </div>
          ${styleBarHTML()}
          <div class="viq-add-hint" id="viq-time-hint">⏱ at 0:00</div>
        </div>
      </div>
    `;
  }

  // ── DANMU STYLE BAR ──────────────────────────────────────────────────────────
  function styleBarHTML() {
    const st  = curStyle();
    const opt = (list, cur, lbl) => list.map(o =>
      '<option value="' + escH(o.id) + '"' + (o.id === cur ? ' selected' : '') + '>' + escH(lbl(o)) + '</option>').join('');
    const fixed = st.mode === 'top' || st.mode === 'bottom';
    return `
      <div class="viq-style-bar" id="viq-style-bar">
        <div class="viq-style-row">
          <select id="viq-st-font" class="viq-st-select" title="Font">${opt(FONTS, st.font, o => o.label)}</select>
          <select id="viq-st-size" class="viq-st-select" title="Size">${opt(SIZES, st.size, o => o.label)}</select>
          <input  id="viq-st-color" type="color" class="viq-st-color" value="${escH(st.color)}" title="Danmu color"/>
          <button id="viq-emoji-btn" class="viq-st-emoji viq-emoji-toggle" title="Emotion emoji">😊</button>
        </div>
        <div class="viq-style-row">
          <select id="viq-st-mode" class="viq-st-select viq-st-mode" title="Position">${opt(MODES, st.mode, o => o.label)}</select>
          <select id="viq-st-dur" class="viq-st-select ${fixed ? '' : 'hidden'}" title="How long it stays on screen">
            ${DURATIONS.map(d => '<option value="' + d + '"' + (d === Number(st.duration) ? ' selected' : '') + '>' + d + 's</option>').join('')}
          </select>
          <button id="viq-st-preview" class="viq-st-preview" title="Preview on video">▶ Preview</button>
        </div>
        <div class="viq-st-sample" id="viq-st-sample">Aa 弹幕 😊</div>
      </div>`;
  }

  function wireStyleBar() {
    const g = id => document.getElementById(id);
    const onChange = () => {
      const mode = g('viq-st-mode').value;
      settings.danmuStyle = {
        font:     g('viq-st-font').value,
        size:     g('viq-st-size').value,
        color:    g('viq-st-color').value,
        mode,
        duration: parseInt(g('viq-st-dur').value, 10) || DEFAULT_STYLE.duration
      };
      g('viq-st-dur').classList.toggle('hidden', mode !== 'top' && mode !== 'bottom');
      save();   // persisted — stays until the next change
      updateStyleSample();
    };
    ['viq-st-font','viq-st-size','viq-st-mode','viq-st-dur'].forEach(id => g(id).onchange = onChange);
    g('viq-st-color').oninput = onChange;
    g('viq-st-preview').onclick = () =>
      launchFloat({ user: settings.username, color: settings.color, text: 'Preview 预览 😊', style: curStyle() });
    updateStyleSample();
  }

  function updateStyleSample() {
    const el = document.getElementById('viq-st-sample'); if (!el) return;
    const st = curStyle();
    el.style.color      = st.color;
    el.style.fontFamily = (FONTS.find(f => f.id === st.font) || FONTS[0]).css + ',' + EMOJI_FALLBACK;
    el.style.fontSize   = Math.min((SIZES.find(z => z.id === st.size) || SIZES[1]).px, 24) + 'px';
  }

  // ── EMOJI PICKER ─────────────────────────────────────────────────────────────
  let emojiTarget = null;   // the input that last had focus (main textarea or mini input)

  function wireEmojiPicker() {
    const picker = document.getElementById('viq-emoji-picker');
    ['viq-quick-input','viq-mini-input'].forEach(id => {
      document.getElementById(id).addEventListener('focus', e => { emojiTarget = e.target; });
    });
    document.querySelectorAll('.viq-emoji-toggle').forEach(btn => {
      btn.onclick = e => {
        e.stopPropagation();
        if (!emojiTarget || emojiTarget.offsetParent === null)
          emojiTarget = document.getElementById(settings.minimized ? 'viq-mini-input' : 'viq-quick-input');
        // Show the grid next to whichever input is in use: under the header when
        // minimized, right above the style bar when the panel is open.
        const anchor = settings.minimized
          ? document.getElementById('viq-drag-handle').nextSibling
          : document.getElementById('viq-style-bar');
        if (picker.nextSibling !== anchor) anchor.parentNode.insertBefore(picker, anchor);
        picker.classList.toggle('hidden');
      };
    });
    picker.querySelectorAll('.viq-emoji').forEach(b => {
      b.onmousedown = e => e.preventDefault();   // keep caret position in the input
      b.onclick = e => { e.stopPropagation(); insertAtCaret(emojiTarget, b.dataset.emoji); };
    });
    document.addEventListener('click', e => {
      if (!picker.contains(e.target)) picker.classList.add('hidden');
    });
  }

  function insertAtCaret(inp, text) {
    if (!inp) return;
    const a = inp.selectionStart ?? inp.value.length, b = inp.selectionEnd ?? inp.value.length;
    if (inp.maxLength > 0 && inp.value.length - (b - a) + text.length > inp.maxLength) return;
    inp.value = inp.value.slice(0, a) + text + inp.value.slice(b);
    inp.focus();
    inp.setSelectionRange(a + text.length, a + text.length);
  }

  // ── WIRE ─────────────────────────────────────────────────────────────────────
  function wirePanel() {
    wireStyleBar();
    wireEmojiPicker();
    makeDraggable(sidePanel, document.getElementById('viq-drag-handle'));
    document.getElementById('viq-minimize-btn').onclick = toggleMinimized;

    // mini bar
    document.getElementById('viq-mini-send').onclick    = miniSend;
    document.getElementById('viq-mini-input').onkeydown = e => { if (e.key==='Enter') miniSend(); };
    document.getElementById('viq-mini-pause').onclick   = togglePause;
    document.getElementById('viq-mini-summary').onclick = openSummary;

    // settings
    document.getElementById('viq-settings-btn').onclick = () => {
      document.getElementById('viq-settings-panel').classList.toggle('hidden');
      buildAuthorColorRows();
    };
    document.getElementById('viq-save-settings').onclick = doSaveSettings;

    // note input
    const inp = document.getElementById('viq-quick-input');
    inp.onkeydown = e => {
      if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); quickAdd(); }
      if (e.key === 'Escape') cancelEdit();
    };
    document.getElementById('viq-quick-add').onclick   = quickAdd;
    document.getElementById('viq-cancel-edit').onclick = cancelEdit;
    document.getElementById('viq-pause-btn').onclick   = togglePause;
    document.getElementById('viq-summary-btn').onclick = openSummary;
    document.getElementById('viq-export-btn').onclick  = exportMyNotes;

    // import
    document.getElementById('viq-import-btn').onclick = () =>
      document.getElementById('viq-file-input').click();
    document.getElementById('viq-file-input').onchange = e => {
      const f = e.target.files[0]; if (!f) return;
      const r = new FileReader();
      r.onload = ev => { showOffsetDialog(ev.target.result); e.target.value = ''; };
      r.readAsText(f);
    };

    // import offset dialog
    document.getElementById('viq-offset-cancel').onclick = () => {
      document.getElementById('viq-offset-dialog').classList.add('hidden');
      document.getElementById('viq-panel-body').style.display = '';
      pendingImport = null;
    };
    document.getElementById('viq-offset-confirm').onclick = confirmImport;

    // publish
    const pubBtn = document.getElementById('viq-publish-btn');
    if (pubBtn) {
      pubBtn.onclick = openPublishDialog;
      document.getElementById('viq-pd-cancel').onclick  = closePublishDialog;
      document.getElementById('viq-pd-confirm').onclick = doPublish;
      document.getElementById('viq-pd-name').oninput    = updatePublishPreview;
      document.getElementById('viq-pd-color').oninput   = updatePublishPreview;
    }

    setInterval(updateHint, 500);
    document.querySelectorAll('.viq-filter').forEach(btn => {
      btn.onclick = () => {
        document.querySelectorAll('.viq-filter').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        refreshSideList(btn.dataset.filter);
      };
    });
  }

  // ── PUBLISH DIALOG ────────────────────────────────────────────────────────────
  function openPublishDialog() {
    const myNotes = (localNotes[videoId]||[]).filter(n => n.user === settings.username);
    if (!myNotes.length) { flashHint('No notes to publish yet'); return; }
    updatePublishPreview();
    document.getElementById('viq-publish-dialog').classList.remove('hidden');
    document.getElementById('viq-panel-body').style.display = 'none';
  }

  function closePublishDialog() {
    document.getElementById('viq-publish-dialog').classList.add('hidden');
    document.getElementById('viq-panel-body').style.display = '';
    document.getElementById('viq-pd-msg').textContent = '';
  }

  function updatePublishPreview() {
    const name  = document.getElementById('viq-pd-name')?.value || settings.username;
    const color = document.getElementById('viq-pd-color')?.value || settings.color;
    const myNotes = (localNotes[videoId]||[]).filter(n => n.user === settings.username);
    const preview = document.getElementById('viq-pd-preview');
    if (!preview) return;
    const sample = myNotes.slice(0,3).map(n =>
      '<div class="viq-pd-note">' +
        '<span class="viq-item-time">' + n.ts + '</span>' +
        '<span class="viq-item-user" style="color:' + escH(color) + '">' + escH(name) + '</span>' +
        '<span class="viq-item-text">' + escH(n.text) + '</span>' +
      '</div>'
    ).join('');
    preview.innerHTML =
      '<div class="viq-pd-preview-title">' + myNotes.length + ' notes will be posted as:</div>' +
      sample +
      (myNotes.length > 3 ? '<div style="color:#8892aa;font-size:11px;padding:4px 0">…and ' + (myNotes.length-3) + ' more</div>' : '');
  }

  async function doPublish() {
    const name   = (document.getElementById('viq-pd-name').value.trim() || 'Anonymous');
    const color  = document.getElementById('viq-pd-color').value;
    const msg    = document.getElementById('viq-pd-msg');
    const btn    = document.getElementById('viq-pd-confirm');
    const myNotes = (localNotes[videoId]||[]).filter(n => n.user === settings.username);
    if (!myNotes.length) { msg.textContent = 'No notes to post.'; return; }

    msg.textContent = 'Posting…'; msg.style.color = '#8892aa';
    btn.disabled = true;

    // Strip internal fields before posting
    const clean = myNotes.map(n => ({
      text: n.text, time: n.time, ts: n.ts,
      isSummary: n.isSummary || false,
      style: n.style || null
    }));

    try {
      await VIQ_CLOUD.postNotes({
        videoId,
        videoTitle: document.title.replace(' - YouTube','').trim(),
        authorName: name,
        color,
        notes: clean
      });
      msg.textContent = '✓ Posted! Others can now see your notes.';
      msg.style.color = '#34d399';
      setTimeout(closePublishDialog, 2000);
      // Reload cloud posts so your own post appears
      await loadCloudPosts();
    } catch (e) {
      msg.textContent = '❌ ' + e.message;
      msg.style.color = '#f87171';
    }
    btn.disabled = false;
  }

  // ── USER SELECTOR ─────────────────────────────────────────────────────────────
  // Shows each cloud author as a row with: toggle, color, name, offset slider
  function buildUserSelector() {
    const el = document.getElementById('viq-user-selector'); if (!el) return;
    if (!cloudAuthors.length) {
      el.classList.add('hidden');
      return;
    }
    el.classList.remove('hidden');

    el.innerHTML =
      '<div class="viq-us-title">👥 Others\' notes loaded — check to show on video, drag to adjust timing</div>' +
      cloudAuthors.map(post => {
        const name   = post.author_name;
        const color  = post.color;
        const offset = userOffsets[name] || 0;
        const active = visibleUsers === null || visibleUsers.has(name);
        return (
          '<div class="viq-us-row" data-author="' + escH(name) + '">' +
            '<label class="viq-us-toggle">' +
              '<input type="checkbox" class="viq-us-check" data-author="' + escH(name) + '" ' + (active?'checked':'') + '/>' +
              '<span class="viq-us-name" style="color:' + escH(color) + '">' + escH(name) + '</span>' +
              '<span class="viq-us-count">' + (post.notes||[]).length + ' notes</span>' +
            '</label>' +
            '<div class="viq-us-offset">' +
              '<span class="viq-us-offset-lbl" title="Drag left to see notes earlier (good for hints/prompts). Drag right to see notes later (good for answers).">' +
                '⏱ offset: <b id="viq-off-val-' + escH(name) + '">' + (offset >= 0 ? '+' : '') + offset + 's</b>' +
                ' <span class="viq-us-offset-hint">' + (offset < 0 ? '(earlier)' : offset > 0 ? '(later)' : '(same time)') + '</span>' +
              '</span>' +
              '<input type="range" class="viq-us-slider" data-author="' + escH(name) + '"' +
                ' min="-15" max="15" step="1" value="' + offset + '">' +
            '</div>' +
          '</div>'
        );
      }).join('');

    // Wire checkboxes — controls what floats ON VIDEO; sidebar always shows all
    el.querySelectorAll('.viq-us-check').forEach(cb => {
      cb.onchange = () => {
        const checked = new Set();
        el.querySelectorAll('.viq-us-check').forEach(c => { if (c.checked) checked.add(c.dataset.author); });
        const allNames = cloudAuthors.map(p => p.author_name);
        // If all checked → visibleUsers = null (all on video)
        visibleUsers = (checked.size === allNames.length) ? null : checked;
        rebuildActive();
        refreshSideList(); // re-render sidebar so eye badges update
      };
    });

    // Wire offset sliders
    el.querySelectorAll('.viq-us-slider').forEach(slider => {
      slider.oninput = () => {
        const author = slider.dataset.author;
        const val    = parseInt(slider.value);
        userOffsets[author] = val;
        const lbl = document.getElementById('viq-off-val-' + author);
        if (lbl) lbl.textContent = (val >= 0 ? '+' : '') + val + 's';
        // update the hint text
        const row = slider.closest('.viq-us-row');
        const hint = row?.querySelector('.viq-us-offset-hint');
        if (hint) hint.textContent = val < 0 ? '(earlier)' : val > 0 ? '(later)' : '(same time)';
        rebuildActive();
      };
      slider.onchange = () => { refreshSideList(); };
    });
  }

  // ── MINIMIZE ──────────────────────────────────────────────────────────────────
  function toggleMinimized() { setMinimized(!settings.minimized); }

  function setMinimized(mini) {
    settings.minimized = mini; save();
    const body    = document.getElementById('viq-panel-body');
    const miniBar = document.getElementById('viq-mini-bar');
    const minBtn  = document.getElementById('viq-minimize-btn');
    const logo    = sidePanel.querySelector('.viq-logo');
    const actions = document.getElementById('viq-header-actions');
    if (!body||!miniBar) return;
    if (mini) {
      body.classList.add('hidden');
      miniBar.classList.remove('hidden');
      if (actions) actions.classList.add('hidden');
      minBtn.textContent = '+';
      logo?.classList.add('viq-logo-hidden');
      updateMiniPlaceholder();
      setTimeout(() => document.getElementById('viq-mini-input')?.focus(), 50);
    } else {
      body.classList.remove('hidden');
      miniBar.classList.add('hidden');
      if (actions) actions.classList.remove('hidden');
      minBtn.textContent = '–';
      logo?.classList.remove('viq-logo-hidden');
    }
  }

  function updateMiniPlaceholder() {
    const inp = document.getElementById('viq-mini-input');
    if (inp && videoEl) inp.placeholder = 'Note @ ' + fmtTime(videoEl.currentTime) + '…';
  }

  function miniSend() {
    const inp  = document.getElementById('viq-mini-input');
    const text = inp.value.trim(); if (!text) return;
    addNote(text, summaryMode);
    inp.value = ''; summaryMode = false;
    if (pausedForNote && videoEl) { videoEl.play(); pausedForNote = false; }
    updateMiniPlaceholder();
  }

  // ── DRAG ─────────────────────────────────────────────────────────────────────
  function makeDraggable(panel, handle) {
    let ox, oy, ol, ot, drag = false;
    handle.addEventListener('mousedown', e => {
      if (['BUTTON','INPUT','SELECT','TEXTAREA'].includes(e.target.tagName)) return;
      drag = true; ox = e.clientX; oy = e.clientY;
      ol = parseInt(panel.style.left)||0; ot = parseInt(panel.style.top)||0;
      handle.style.cursor = 'grabbing'; e.preventDefault();
    });
    document.addEventListener('mousemove', e => {
      if (!drag) return;
      panel.style.left = clamp(ol+e.clientX-ox, 0, window.innerWidth -panel.offsetWidth)  + 'px';
      panel.style.top  = clamp(ot+e.clientY-oy, 0, window.innerHeight-panel.offsetHeight) + 'px';
    });
    document.addEventListener('mouseup', () => {
      if (!drag) return; drag = false; handle.style.cursor = 'grab';
      settings.panelX = parseInt(panel.style.left);
      settings.panelY = parseInt(panel.style.top);
      save();
    });
  }

  function buildToggleButton() {
    if (document.getElementById('viq-toggle-btn')) return;
    const btn = document.createElement('button');
    btn.id = 'viq-toggle-btn'; btn.textContent = '📝';
    btn.onclick = () => {
      const v = sidePanel.style.display !== 'none';
      sidePanel.style.display = v ? 'none' : 'flex';
      btn.textContent = v ? '📝' : '✕';
    };
    document.body.appendChild(btn);
  }

  // ── PAUSE / SUMMARY ───────────────────────────────────────────────────────────
  function togglePause() {
    if (!videoEl) return;
    if (!pausedForNote) { videoEl.pause(); pausedForNote = true; document.getElementById('viq-quick-input')?.focus(); }
    else { videoEl.play(); pausedForNote = false; }
    const mb = document.getElementById('viq-mini-pause');
    if (mb) { mb.textContent = pausedForNote ? '▶' : '⏸'; mb.classList.toggle('active', pausedForNote); }
    updateHint();
  }

  function openSummary() {
    summaryMode = true;
    if (videoEl) videoEl.pause(); pausedForNote = true;
    const el = id => document.getElementById(id);
    if (el('viq-add-label')) el('viq-add-label').textContent = '📋 Video Summary';
    if (el('viq-time-hint')) el('viq-time-hint').textContent = '📌 Saved at end (' + fmtTime(videoEl?.duration||0) + ')';
    if (el('viq-quick-add')) el('viq-quick-add').textContent = 'Save';
    el('viq-cancel-edit')?.classList.remove('hidden');
    if (el('viq-quick-input')) { el('viq-quick-input').placeholder = 'Write your overall summary…'; el('viq-quick-input').focus(); }
    if (el('viq-mini-input'))  { el('viq-mini-input').placeholder = 'Summary…'; el('viq-mini-input').focus(); }
    el('viq-mini-summary')?.classList.add('active');
  }

  function closeSummary() {
    summaryMode = false;
    const el = id => document.getElementById(id);
    if (el('viq-add-label')) el('viq-add-label').textContent = '✍️ Add note';
    if (el('viq-quick-add')) el('viq-quick-add').textContent = editingId !== null ? 'Save' : 'Send';
    if (editingId === null) el('viq-cancel-edit')?.classList.add('hidden');
    if (el('viq-quick-input')) el('viq-quick-input').placeholder = 'Type here… Enter to send, Shift+Enter for new line';
    el('viq-mini-summary')?.classList.remove('active');
  }

  function updateHint() {
    const hint    = document.getElementById('viq-time-hint');
    const pauseBtn = document.getElementById('viq-pause-btn');
    if (hint && editingId===null && !summaryMode && videoEl)
      hint.textContent = '⏱ will be added at ' + fmtTime(videoEl.currentTime);
    if (pauseBtn) {
      pauseBtn.textContent = pausedForNote ? '▶ Resume' : '⏸ Pause';
      pauseBtn.classList.toggle('paused', pausedForNote);
    }
    if (settings.minimized) updateMiniPlaceholder();
  }

  // ── ADD / EDIT NOTES ──────────────────────────────────────────────────────────
  function quickAdd() {
    const inp  = document.getElementById('viq-quick-input');
    const text = inp.value.trim(); if (!text) return;
    if (editingId !== null) { commitEdit(text); inp.value = ''; cancelEdit(); return; }
    if (summaryMode) {
      addNote(text, true); inp.value = ''; closeSummary();
      if (pausedForNote && videoEl) { videoEl.play(); pausedForNote = false; }
      return;
    }
    addNote(text, false); inp.value = '';
    if (pausedForNote && videoEl) { videoEl.play(); pausedForNote = false; }
    inp.focus();
  }

  function addNote(text, isSummary) {
    let time = videoEl ? videoEl.currentTime : 0;
    if (isSummary && videoEl?.duration) time = videoEl.duration;
    const note = {
      id: Date.now(), user: settings.username, color: settings.color,
      text, time: Math.floor(time), ts: fmtTime(time),
      isSummary: isSummary||false, videoId,
      style: curStyle()
    };
    if (!localNotes[videoId]) localNotes[videoId] = [];
    localNotes[videoId].push(note);
    save();
    saveVideoTitle(document.title.replace(' - YouTube','').trim());
    rebuildActive();
    if (settings.showOnVideo && !isSummary) launchFloat(note);
    refreshSideList();
  }

  function startEdit(id) {
    const note = (localNotes[videoId]||[]).find(n => n.id === id); if (!note) return;
    if (note.user !== settings.username) return;
    editingId = id; summaryMode = false;
    const inp  = document.getElementById('viq-quick-input');
    const btn  = document.getElementById('viq-quick-add');
    const cBtn = document.getElementById('viq-cancel-edit');
    const lbl  = document.getElementById('viq-add-label');
    const hint = document.getElementById('viq-time-hint');
    inp.value = note.text; inp.placeholder = 'Edit note…';
    if (btn)  btn.textContent = 'Save';
    if (cBtn) cBtn.classList.remove('hidden');
    if (lbl)  lbl.textContent  = '✏️ Editing note';
    if (hint) hint.textContent = 'Editing @ ' + note.ts + ' — Enter to save, Esc to cancel';
    if (settings.minimized) setMinimized(false);
    inp.focus(); inp.setSelectionRange(inp.value.length, inp.value.length);
    refreshSideList();
  }

  function commitEdit(text) {
    const note = (localNotes[videoId]||[]).find(n => n.id === editingId); if (!note) return;
    note.text = text; save(); rebuildActive();
  }

  function cancelEdit() {
    editingId = null; summaryMode = false;
    const el = id => document.getElementById(id);
    if (el('viq-quick-input')) { el('viq-quick-input').value = ''; el('viq-quick-input').placeholder = 'Type here… Enter to send, Shift+Enter for new line'; }
    if (el('viq-quick-add'))   el('viq-quick-add').textContent = 'Send';
    el('viq-cancel-edit')?.classList.add('hidden');
    if (el('viq-add-label'))   el('viq-add-label').textContent = '✍️ Add note';
    refreshSideList();
  }

  function deleteNote(id) {
    if (!localNotes[videoId]) return;
    localNotes[videoId] = localNotes[videoId].filter(n => n.id !== id);
    save(); rebuildActive(); refreshSideList();
  }

  // ── EXPORT ───────────────────────────────────────────────────────────────────
  function exportMyNotes() {
    const notes = (localNotes[videoId]||[]).filter(n => n.user === settings.username);
    if (!notes.length) { flashHint('No notes of yours to export'); return; }
    const title   = document.title.replace(' - YouTube','').trim();
    const payload = {
      _meta: { author: settings.username, color: settings.color, exportedAt: new Date().toISOString(), videoTitle: title, videoId },
      [videoId]: notes
    };
    const slug = title.replace(/[^a-z0-9]/gi,'_').slice(0,40);
    const blob = new Blob([JSON.stringify(payload,null,2)],{type:'application/json'});
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement('a');
    a.href=url; a.download='videoiq_'+settings.username+'_'+slug+'.json'; a.click();
    URL.revokeObjectURL(url); flashHint('✓ Exported!');
  }

  // ── IMPORT WITH OFFSET ────────────────────────────────────────────────────────
  let pendingImport = null;
  const HINT_W   = ['hint','name','emotion','feel','who','what','where','when','identify','guess'];
  const ANSWER_W = ['answer','key','correct','result','because','reason','explain','how','why'];

  function detectCat(text) {
    const t = text.toLowerCase();
    if (HINT_W.some(w=>t.includes(w)))   return 'hint';
    if (ANSWER_W.some(w=>t.includes(w))) return 'answer';
    return 'normal';
  }

  function showOffsetDialog(jsonText) {
    let inc; try { inc = JSON.parse(jsonText); } catch { flashHint('❌ Invalid JSON'); return; }
    pendingImport = inc;
    const meta = inc._meta||{};
    const titleEl = document.getElementById('viq-offset-title');
    if (titleEl && meta.author) {
      const c = meta.color||'#8892aa';
      titleEl.innerHTML = '⏱ Import from <span style="color:' + escH(c) + ';font-weight:800">' + escH(meta.author) + '</span>' +
        (meta.exportedAt ? ' <span style="color:#8892aa;font-size:10px">· ' + new Date(meta.exportedAt).toLocaleString() + '</span>' : '') +
        (meta.videoTitle ? '<br><span style="color:#8892aa;font-size:10px">📹 ' + escH(meta.videoTitle) + '</span>' : '');
    }
    const authors = new Set();
    for (const v in inc) { if (v==='_meta') continue; (inc[v]||[]).forEach(e=>{ if(e.user) authors.add(e.user); }); }
    if (meta.author) authors.add(meta.author);

    const rows = document.getElementById('viq-offset-rows');
    rows.innerHTML = [...authors].map(author => {
      let h=0,a=0,n=0;
      for (const v in inc) {
        if (v==='_meta') continue;
        (inc[v]||[]).filter(e=>e.user===author).forEach(e=>{const c=detectCat(e.text);if(c==='hint')h++;else if(c==='answer')a++;else n++;});
      }
      let color = meta.color||'#8892aa';
      outer: for (const v in inc) {
        if (v==='_meta') continue;
        for (const e of (inc[v]||[])) { if(e.user===author&&e.color){color=e.color;break outer;} }
      }
      return (
        '<div class="viq-offset-row" data-author="' + escH(author) + '">' +
          '<div class="viq-offset-who">' +
            '<input type="color" class="viq-author-color-pick" value="' + escH(color) + '"' +
              ' oninput="this.closest(\'.viq-offset-row\').querySelector(\'.viq-offset-user\').style.color=this.value"/>' +
            '<span class="viq-offset-user" style="color:' + escH(color) + '">' + escH(author) + '</span>' +
            (author===meta.author?'<span class="viq-offset-file-author">✦ file author</span>':'') +
            '<span class="viq-offset-counts">' + (h+a+n) + ' notes · ' + h + ' hints · ' + a + ' answers</span>' +
          '</div>' +
          '<div class="viq-offset-fields">' +
            '<label class="viq-offset-field"><span>💡 Hint (s)</span><input type="number" class="viq-offset-input" data-cat="hint" value="-2" min="-30" max="30" step="1"/></label>' +
            '<label class="viq-offset-field"><span>✅ Answer (s)</span><input type="number" class="viq-offset-input" data-cat="answer" value="4" min="-30" max="30" step="1"/></label>' +
            '<label class="viq-offset-field"><span>📝 Other (s)</span><input type="number" class="viq-offset-input" data-cat="normal" value="0" min="-30" max="30" step="1"/></label>' +
          '</div>' +
        '</div>'
      );
    }).join('')||'<div style="color:#8892aa;font-size:12px;padding:8px">No notes in file.</div>';

    document.getElementById('viq-offset-dialog').classList.remove('hidden');
    document.getElementById('viq-panel-body').style.display = 'none';
  }

  function confirmImport() {
    document.getElementById('viq-offset-dialog').classList.add('hidden');
    document.getElementById('viq-panel-body').style.display = '';
    if (!pendingImport) return;
    const offsets={}, colors={};
    document.querySelectorAll('.viq-offset-row').forEach(row=>{
      const au=row.dataset.author; offsets[au]={};
      row.querySelectorAll('.viq-offset-input').forEach(i=>{offsets[au][i.dataset.cat]=parseInt(i.value)||0;});
      const cp=row.querySelector('.viq-author-color-pick'); if(cp) colors[au]=cp.value;
    });
    let added=0;
    for (const v in pendingImport) {
      if (v==='_meta') continue;
      if (!localNotes[v]) localNotes[v]=[];
      const ids=new Set(localNotes[v].map(n=>n.id));
      for (const e of (pendingImport[v]||[])) {
        if (ids.has(e.id)) continue;
        const ao=offsets[e.user]||{hint:0,answer:0,normal:0};
        const sh=ao[detectCat(e.text)]||0;
        localNotes[v].push(Object.assign({},e,{
          time:Math.max(0,(e.time||0)+sh), ts:fmtTime(Math.max(0,(e.time||0)+sh)),
          _offset:sh, color:colors[e.user]||e.color
        }));
        added++;
      }
    }
    pendingImport=null; save(); rebuildActive(); refreshSideList();
    flashHint('✓ Merged ' + added + ' note' + (added!==1?'s':''));
  }

  // ── AUTHOR RECOLOR ────────────────────────────────────────────────────────────
  function buildAuthorColorRows() {
    const c = document.getElementById('viq-author-colors'); if (!c) return;
    const others = {};
    (localNotes[videoId]||[]).forEach(n=>{if(n.user!==settings.username) others[n.user]=others[n.user]||n.color||'#8892aa';});
    cloudAuthors.forEach(p=>{if(p.author_name!==settings.username) others[p.author_name]=others[p.author_name]||p.color||'#8892aa';});
    if (!Object.keys(others).length) { c.innerHTML=''; return; }
    c.innerHTML = '<div class="viq-author-colors-title">Other authors\' colors</div>' +
      Object.entries(others).map(([user,color])=>
        '<div class="viq-setting-row">' +
          '<label style="color:'+escH(color)+';font-weight:600">'+escH(user)+'</label>' +
          '<div style="display:flex;gap:6px;align-items:center">' +
            '<input type="color" class="viq-author-color-pick-live" value="'+escH(color)+'" data-user="'+escH(user)+'"' +
              ' oninput="this.closest(\'.viq-setting-row\').querySelector(\'label\').style.color=this.value"/>' +
            '<button class="viq-recolor-btn" data-user="'+escH(user)+'">Apply</button>' +
          '</div>' +
        '</div>'
      ).join('');
    c.querySelectorAll('.viq-recolor-btn').forEach(btn=>{
      btn.onclick=()=>{
        const user=btn.dataset.user;
        const pick=c.querySelector('.viq-author-color-pick-live[data-user="'+user+'"]');
        const col=pick?pick.value:'#8892aa';
        for (const v in localNotes) localNotes[v].forEach(n=>{if(n.user===user) n.color=col;});
        cloudAuthors.forEach(p=>{if(p.author_name===user) p.color=col;});
        save(); rebuildActive(); refreshSideList(); buildAuthorColorRows(); buildUserSelector();
        flashHint('✓ Recolored '+user);
      };
    });
  }

  // ── FLOATING DANMU ────────────────────────────────────────────────────────────
  // Lanes for top/bottom danmu so simultaneous ones stack instead of overlapping
  const fixedLanes = { top: [], bottom: [] };

  function launchFloat(entry, opts) {
    if (!danmuContainer) return;
    const st   = Object.assign({}, DEFAULT_STYLE, entry.style || {});
    const font = FONTS.find(f => f.id === st.font) || FONTS[0];
    const px   = (SIZES.find(z => z.id === st.size) || SIZES[1]).px;
    const mode = MODES.some(m => m.id === st.mode) ? st.mode : 'rtl';
    const dur  = clamp(Number(st.duration) || DEFAULT_STYLE.duration, 1, 60);

    const el = document.createElement('div');
    el.className   = 'viq-float viq-float-' + mode;
    el.textContent = (opts && opts.noName ? '' : '[' + (entry.user||entry.username) + '] ') + entry.text;
    el.style.color      = st.color || entry.color;
    el.style.fontFamily = font.css + ',' + EMOJI_FALLBACK;
    el.style.fontSize   = px + 'px';

    let lifeMs;
    if (mode === 'top' || mode === 'bottom') {
      const lanes  = fixedLanes[mode];
      const now    = Date.now();
      const laneH  = Math.round(px * 1.6);
      const maxL   = Math.max(1, Math.floor((danmuContainer.clientHeight || 360) * 0.45 / laneH));
      let lane = lanes.findIndex((until, i) => i < maxL && until <= now);
      if (lane === -1) lane = lanes.length < maxL ? lanes.length
                              : lanes.indexOf(Math.min(...lanes.slice(0, maxL)));
      lanes[lane] = now + dur * 1000;
      el.style[mode] = (8 + lane * laneH) + 'px';
      el.style.animationDuration = dur + 's';
      lifeMs = dur * 1000;
    } else {
      el.style.top = (10 + Math.random() * 70) + '%';
      lifeMs = 7000;
    }
    danmuContainer.appendChild(el);
    setTimeout(() => el.remove(), lifeMs + 200);
  }
  function clearDanmuOverlay() { if (danmuContainer) danmuContainer.innerHTML = ''; }

  // ── TIME LOOP ─────────────────────────────────────────────────────────────────
  function startLoop() {
    cancelAnimationFrame(animFrame);
    (function tick() {
      if (!videoEl||videoEl.readyState===undefined) videoEl=document.querySelector('video');
      if (videoEl) {
        const t = Math.floor(videoEl.currentTime);
        if (t !== lastTime) { lastTime=t; checkTime(t); highlightList(t); }
      }
      animFrame = requestAnimationFrame(tick);
    })();
  }

  function checkTime(t) {
    if (!settings.showOnVideo) return;
    activeDanmu.filter(d => {
      if (d.time!==t || d.isSummary||d.is_summary) return false;
      const user = d.user||d.username;
      if (user === settings.username) return settings.showOwn;
      return true;
    }).forEach(d => launchFloat(d));
  }

  function highlightList(t) {
    document.querySelectorAll('.viq-list-item').forEach(el => {
      const dt=parseInt(el.dataset.time,10);
      el.classList.toggle('active-now', Math.abs(dt-t)<=1 && !el.classList.contains('summary-note'));
    });
  }

  // ── SIDE LIST ─────────────────────────────────────────────────────────────────
  // Sidebar ALWAYS shows all notes (allDanmu), sorted by adjusted timestamp.
  // The video overlay checkbox only affects what floats on screen, not the sidebar.
  function refreshSideList(filter) {
    filter = filter || document.querySelector('.viq-filter.active')?.dataset.filter || 'all';
    const list = document.getElementById('viq-danmu-list'); if (!list) return;
    if (filter === 'compare') { renderCompare(list); return; }

    // Always use allDanmu for sidebar — already sorted by adjusted time
    let items = allDanmu.slice();
    if (filter==='mine')   items=items.filter(d=>(d.user||d.username)===settings.username);
    if (filter==='others') items=items.filter(d=>(d.user||d.username)!==settings.username);

    if (!items.length) { list.innerHTML='<div class="viq-empty">No notes yet.</div>'; return; }
    list.innerHTML = items.map(d => noteHTML(d, filter)).join('');
    wireList(list);
  }

  function noteHTML(d, filter) {
    const user      = d.user||d.username;
    const isOwn     = user===settings.username;
    const isSummary = d.isSummary||d.is_summary;
    const isEditing = d.id===editingId;
    // dim notes that are NOT shown on video (unchecked in selector)
    const onVideo   = isOwn || visibleUsers === null || (visibleUsers && visibleUsers.has(user));
    const offBadge  = d._offset ? '<span class="viq-offset-badge">'+(d._offset>0?'+':'')+d._offset+'s</span>' : '';
    const cloudBadge= d._cloud  ? '<span class="viq-cloud-badge" title="Public post">☁</span>' : '';
    const eyeBadge  = (!onVideo && !isOwn) ? '<span class="viq-hidden-badge" title="Not shown on video">👁</span>' : '';
    const cls = [isOwn?'own':'other', isSummary?'summary-note':'', isEditing?'editing':'', !onVideo&&!isOwn?'note-dimmed':''].filter(Boolean).join(' ');
    return (
      '<div class="viq-list-item '+cls+'" data-time="'+d.time+'" data-id="'+d.id+'">' +
        '<div class="viq-item-main">' +
          '<span class="viq-item-time" data-time="'+d.time+'">'+(isSummary?'📋':d.ts)+'</span>' +
          '<span class="viq-item-user" style="color:'+escH(d.color)+'">'+escH(user)+'</span>' +
          (isSummary?'<span class="viq-summary-tag">Summary</span>':'') +
          offBadge+cloudBadge+eyeBadge+
          '<span class="viq-item-text '+(isOwn?'editable':'')+'" data-id="'+d.id+'">'+escH(d.text)+'</span>' +
        '</div>' +
        '<div class="viq-item-actions">'+(isOwn?'<button class="viq-del" data-id="'+d.id+'">✕</button>':'')+'</div>' +
      '</div>'
    );
  }

  function renderCompare(list) {
    // Compare view also uses allDanmu so all notes are visible regardless of video filter
    const mine   = allDanmu.filter(d=>(d.user||d.username)===settings.username).sort((a,b)=>a.time-b.time);
    const others = allDanmu.filter(d=>(d.user||d.username)!==settings.username).sort((a,b)=>a.time-b.time);
    if (!mine.length&&!others.length) { list.innerHTML='<div class="viq-empty">No notes to compare.</div>'; return; }
    const all=[...mine.map(d=>({...d,_s:'mine'})),...others.map(d=>({...d,_s:'other'}))].sort((a,b)=>a.time-b.time);
    const clusters=[]; let cl=[];
    for (const item of all) {
      if (!cl.length||item.time-cl[cl.length-1].time<=5) cl.push(item);
      else { clusters.push(cl); cl=[item]; }
    }
    if (cl.length) clusters.push(cl);
    list.innerHTML =
      '<div class="viq-compare-header">' +
        '<div class="viq-compare-hcol" style="color:#4f9eff">🔵 '+escH(settings.username)+'</div>' +
        '<div class="viq-compare-hcol" style="color:#a78bfa">🟣 Others</div>' +
      '</div>' +
      clusters.map(cl=>{
        const mi=cl.filter(d=>d._s==='mine'), ot=cl.filter(d=>d._s==='other');
        return '<div class="viq-compare-cluster">'+
          '<div class="viq-compare-ts" data-time="'+cl[0].time+'">'+cl[0].ts+'</div>'+
          '<div class="viq-compare-cols">'+
            '<div class="viq-compare-col viq-compare-mine">'+(mi.map(d=>
              '<div class="viq-compare-note own" data-time="'+d.time+'" data-id="'+d.id+'">'+
                '<span class="viq-compare-user" style="color:'+d.color+'">'+escH(d.user||d.username)+'</span>'+
                '<span class="viq-compare-text editable" data-id="'+d.id+'">'+escH(d.text)+'</span>'+
              '</div>'
            ).join('')||'<div class="viq-compare-empty">—</div>')+'</div>'+
            '<div class="viq-compare-divider"></div>'+
            '<div class="viq-compare-col viq-compare-followed">'+(ot.map(d=>
              '<div class="viq-compare-note other" data-time="'+d.time+'" data-id="'+d.id+'">'+
                '<span class="viq-compare-user" style="color:'+d.color+'">'+escH(d.user||d.username)+'</span>'+
                '<span class="viq-compare-text">'+escH(d.text)+'</span>'+
              '</div>'
            ).join('')||'<div class="viq-compare-empty">—</div>')+'</div>'+
          '</div></div>';
      }).join('');
    list.querySelectorAll('.viq-compare-ts').forEach(el=>{el.onclick=()=>{if(videoEl) videoEl.currentTime=parseInt(el.dataset.time)||0;};});
    list.querySelectorAll('.viq-compare-text.editable').forEach(el=>{el.onclick=e=>{e.stopPropagation();startEdit(parseInt(el.dataset.id));};});
    list.querySelectorAll('.viq-compare-note').forEach(el=>{el.ondblclick=()=>{if(videoEl) videoEl.currentTime=parseInt(el.dataset.time)||0;};});
  }

  function wireList(list) {
    list.querySelectorAll('.viq-item-text.editable').forEach(el=>{ el.onclick=e=>{e.stopPropagation();startEdit(parseInt(el.dataset.id));}; });
    list.querySelectorAll('.viq-list-item').forEach(el=>{ el.ondblclick=()=>{if(videoEl) videoEl.currentTime=parseInt(el.dataset.time)||0;}; });
    list.querySelectorAll('.viq-item-time').forEach(el=>{ el.onclick=e=>{e.stopPropagation();if(videoEl) videoEl.currentTime=parseInt(el.dataset.time)||0;}; });
    list.querySelectorAll('.viq-del').forEach(btn=>{
      btn.onclick=e=>{e.stopPropagation();if(editingId===parseInt(btn.dataset.id)) cancelEdit();deleteNote(parseInt(btn.dataset.id));};
    });
  }

  // ── SETTINGS ─────────────────────────────────────────────────────────────────
  function doSaveSettings() {
    settings.username    = document.getElementById('viq-username').value.trim() || settings.username;
    settings.color       = document.getElementById('viq-color').value;
    settings.showOwn     = document.getElementById('viq-toggle-own').checked;
    settings.showOnVideo = document.getElementById('viq-toggle-video').checked;
    save(); rebuildActive(); updateStyleSample();
    const stc = document.getElementById('viq-st-color'); if (stc) stc.value = curStyle().color;
    document.getElementById('viq-settings-panel').classList.add('hidden');
    refreshSideList();
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────
  function flashHint(msg) {
    const h=document.getElementById('viq-time-hint'); if(!h) return;
    h.textContent=msg; h.style.color=msg.startsWith('❌')?'#f87171':'#34d399';
    setTimeout(()=>{ h.style.color=''; },2500);
  }
  function fmtTime(secs) {
    const s=Math.floor(secs||0),m=Math.floor(s/60),ss=(s%60).toString().padStart(2,'0');
    return m+':'+ss;
  }
  function escH(s) { return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
  function clamp(v,lo,hi) { return Math.max(lo,Math.min(v,hi)); }

  boot();
})();
