// VideoIQ Danmu — web page (phones, tablets, any browser)
// Plays a YouTube video with the official embedded player and floats everyone's
// danmu on top. Same accounts + database as the Chrome extension (cloud.js).
(() => {
  'use strict';

  const C = window.VIQ_CLOUD;
  const $ = id => document.getElementById(id);

  // ── Style options (same ids as the extension, so styles match everywhere) ──
  const EMOJI_FALLBACK = '"Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji",sans-serif';
  const FONTS = [
    { id: 'default', label: 'Default',  css: "-apple-system,BlinkMacSystemFont,'Segoe UI',system-ui" },
    { id: 'arial',   label: 'Arial',    css: 'Arial,Helvetica' },
    { id: 'serif',   label: 'Serif',    css: 'Georgia,"Times New Roman",serif' },
    { id: 'mono',    label: 'Mono',     css: '"Courier New",Consolas,monospace' },
    { id: 'comic',   label: 'Comic',    css: '"Comic Sans MS","Comic Neue",cursive' },
    { id: 'impact',  label: 'Impact',   css: 'Impact,"Arial Black"' },
    { id: 'hei',     label: '黑体 Hei',  css: '"PingFang SC","Microsoft YaHei","Noto Sans SC",SimHei' },
    { id: 'kai',     label: '楷体 Kai',  css: '"Kaiti SC",STKaiti,KaiTi,serif' }
  ];
  const SIZES = [
    { id: 's', label: 'Small', px: 14 }, { id: 'm', label: 'Medium', px: 18 },
    { id: 'l', label: 'Large', px: 24 }, { id: 'xl', label: 'Huge', px: 32 }
  ];
  const MODES = [
    { id: 'rtl', label: '⬅ Scroll' }, { id: 'ltr', label: '➡ Scroll' },
    { id: 'top', label: '⬆ Top' },    { id: 'bottom', label: '⬇ Bottom' }
  ];
  const DURATIONS = [2, 3, 5, 8, 10, 15];
  const EMOJIS = ['😀','😂','🤣','😊','😍','🥰','😎','🤩','😮','😱','🤯','🤔','😐','🙄','😴','😢','😭','😡',
                  '😤','😨','😳','🥺','😅','🤗','👍','👎','👏','🙏','❤️','💔','🔥','💯','🎉','✨','❓','❗'];
  const APP_VERSION = '9';
  // anon: the WRITER hides their name on this danmu; nameTo {id,name}: … except for this one person
  const DEFAULT_STYLE = { font: 'default', size: 'm', color: null, mode: 'rtl', duration: 5, anon: false, nameTo: null };
  const ANON = { name: '🙈 Anonymous', color: '#9ca3af' };
  const isMine = r => { const u = me(); return !!(u && r.user_id === u.id); };
  // How a danmu's author appears to ME: {name, color, hidden, revealed, note}
  function author(r) {
    const base = { name: r.profiles?.display_name || 'Someone', color: r.profiles?.color || '#a78bfa' };
    if (isMine(r)) {
      const anon = !!(r.style && r.style.anon), to = (r.name_to || [])[0];
      return Object.assign(base, { mineAnon: anon,
        note: anon ? (to ? '🔒 ' + (to.name || '1 person') : '🙈') : '',
        tip: anon ? (to ? 'Only ' + (to.name || 'one person') + ' can see your name on this danmu' : 'Your name is hidden on this danmu') : '' });
    }
    if (r.name_hidden) return { name: ANON.name, color: ANON.color, hidden: true };
    if (r.name_revealed) return Object.assign(base, { revealed: true, note: '🔒', tip: 'Only you can see who wrote this' });
    return base;
  }
  const STYLE_KEY = 'viq_web_style', SEEN_KEY = 'viq_web_feed_seen', DANMU_ON_KEY = 'viq_web_danmu_on', NAMES_KEY = 'viq_web_show_names';
  const POLL_MS = 10000, SCROLL_MS = 7000;

  // ── State ──────────────────────────────────────────────────────────────────
  let videoId = null, isShort = false, startAt = 0;
  let player = null, apiReady = false, playerReady = false;
  let rows = [];                 // danmu of this video: {user_id, client_id, time_sec, text, style, profiles:{display_name,color}}
  let pending = new Map();       // client_id → row being saved (kept across polls until confirmed)
  let lastSec = -1, filter = 'all', editing = null;
  let pollTimer = null, tickTimer = null;
  const live = new Set();        // on-screen danmu animations (paused with the video)
  const lanes = { top: [], bottom: [] };
  let danmuOn = lsGet(DANMU_ON_KEY, true);
  let showNames = lsGet(NAMES_KEY, true);   // "[Lin] text" vs just "text" (viewer's choice)

  // ── Helpers ────────────────────────────────────────────────────────────────
  function lsGet(k, d) { try { const v = localStorage.getItem(k); return v === null ? d : JSON.parse(v); } catch { return d; } }
  function lsSet(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch { /* private mode */ } }
  function esc(s) { return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
  function escRe(s) { return String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }
  function fmt(sec) { sec = Math.max(0, Math.floor(sec || 0)); return Math.floor(sec / 60) + ':' + String(sec % 60).padStart(2, '0'); }
  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
  function cleanTitle(t) { return String(t || '').replace(/ - YouTube$/, '').replace(/^\(\d+\)\s*/, '').trim(); }
  function me() { return C && C.getUser(); }
  function composing(e) { return e.isComposing || e.keyCode === 229; }
  let toastT;
  function toast(msg, ms) {
    const t = $('toast'); t.textContent = msg; t.classList.remove('hidden');
    clearTimeout(toastT); toastT = setTimeout(() => t.classList.add('hidden'), ms || 2600);
  }
  function timeAgo(ms) {
    const s = Math.max(0, (Date.now() - ms) / 1000);
    if (s < 60) return 'just now';
    if (s < 3600) return Math.floor(s / 60) + 'm ago';
    if (s < 86400) return Math.floor(s / 3600) + 'h ago';
    if (s < 86400 * 30) return Math.floor(s / 86400) + 'd ago';
    return new Date(ms).toLocaleDateString();
  }

  // ── Links → video id ───────────────────────────────────────────────────────
  // Accepts youtu.be/…, youtube.com/watch?v=…, /shorts/…, /live/…, /embed/…,
  // m.youtube.com, a bare 11-character id, or shared text containing a link.
  function parseVideo(input) {
    const s = String(input || '').trim();
    if (!s) return null;
    if (/^[\w-]{11}$/.test(s)) return { id: s, short: false, t: 0 };
    const inText = s.match(/https?:\/\/\S+/);
    const candidate = inText ? inText[0] : (/^[\w.-]+\.[a-z]{2,}\//i.test(s) ? 'https://' + s : null);
    if (!candidate) return null;
    let u; try { u = new URL(candidate); } catch { return null; }
    const host = u.hostname.replace(/^(www|m|music)\./, '');
    const t = parseT(u.searchParams.get('t') || u.searchParams.get('start'));
    if (host === 'youtu.be') {
      const id = u.pathname.slice(1, 12);
      return /^[\w-]{11}$/.test(id) ? { id, short: false, t } : null;
    }
    if (host === 'youtube.com' || host === 'youtube-nocookie.com') {
      const v = u.searchParams.get('v');
      if (v && /^[\w-]{11}$/.test(v)) return { id: v, short: false, t };
      const m = u.pathname.match(/^\/(shorts|embed|live|v)\/([\w-]{11})/);
      if (m) return { id: m[2], short: m[1] === 'shorts', t };
    }
    return null;
  }
  function parseT(t) {
    if (!t) return 0;
    if (/^\d+$/.test(t)) return +t;
    const m = String(t).match(/(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?/);
    return m ? (+m[1] || 0) * 3600 + (+m[2] || 0) * 60 + (+m[3] || 0) : 0;
  }

  // ── Routing: ?v=ID (&s=1 for Shorts) ─────────────────────────────────────────
  function readUrl() {
    const q = new URLSearchParams(location.search);
    // Shared into the app: ?url=… (iPhone Shortcut) or ?title=…&text=…&url=… (Android Share
    // menu; the YouTube app puts the link in "text" and leaves "url" empty).
    if (q.has('url') || q.has('text') || q.has('title')) {
      const tries = [];
      const i = location.search.indexOf('url=');
      if (i >= 0) {   // raw: a link pasted by the Shortcut may contain unencoded ? and &
        let raw = location.search.slice(i + 4);
        try { raw = decodeURIComponent(raw); } catch { /* already plain */ }
        tries.push(raw);
      }
      tries.push(q.get('url'), q.get('text'), q.get('title'));
      for (const t of tries) {
        const p = t && parseVideo(t);
        if (p) { history.replaceState(null, '', buildUrl(p)); return p; }
      }
      history.replaceState(null, '', location.pathname);
      $('open-msg').textContent = 'That doesn\'t look like a YouTube video link.';
      return null;
    }
    const v = q.get('v');
    return v && /^[\w-]{11}$/.test(v) ? { id: v, short: q.get('s') === '1', t: parseT(q.get('t')) } : null;
  }
  function buildUrl(p) { return '?v=' + p.id + (p.short ? '&s=1' : '') + (p.t ? '&t=' + p.t : ''); }

  function route() {
    const p = readUrl();
    if (p) showWatch(p); else showHome();
  }

  function go(p) {
    history.pushState(null, '', buildUrl(p));
    showWatch(p);
    window.scrollTo(0, 0);
  }

  // ── HOME ───────────────────────────────────────────────────────────────────
  function showHome() {
    stopWatch();
    document.body.classList.remove('watching'); setDrawer(false);
    $('home').classList.remove('hidden'); $('watch').classList.add('hidden');
    document.title = 'VideoIQ Danmu';
    loadFeed();
  }

  $('open-form').onsubmit = e => {
    e.preventDefault();
    const p = parseVideo($('link-input').value);
    if (!p) { $('open-msg').textContent = 'Paste a YouTube link (youtube.com, youtu.be or a Shorts link).'; return; }
    $('open-msg').textContent = ''; $('link-input').value = '';
    go(p);
  };
  $('paste-btn').onclick = async () => {
    try {
      const txt = await navigator.clipboard.readText();
      $('link-input').value = txt;
      const p = parseVideo(txt);
      if (p) { $('open-msg').textContent = ''; $('link-input').value = ''; go(p); }
      else $('open-msg').textContent = 'The clipboard doesn\'t contain a YouTube link.';
    } catch { $('open-msg').textContent = 'Allow clipboard access, or long-press the box and tap Paste.'; }
  };
  $('home-link').onclick = e => { e.preventDefault(); history.pushState(null, '', location.pathname); showHome(); };
  $('shortcut-url').textContent = location.origin + location.pathname + '?url=';

  // Feed: videos with the most recent danmu from everyone
  let feedSeen = lsGet(SEEN_KEY, 0);
  $('feed-refresh').onclick = () => loadFeed();
  async function loadFeed() {
    const list = $('feed-list');
    if (!C.isConfigured()) { list.innerHTML = '<div class="empty">Online danmu are not set up yet.</div>'; return; }
    try {
      const recent = (await C.getRecent(400)) || [];
      const u = me(), map = new Map();
      recent.forEach(r => {
        if (!/^[\w-]{11}$/.test(r.video_id || '')) return;
        const at = Date.parse(r.updated_at) || 0;
        const a = author(r), who = { name: a.name + (a.revealed ? ' 🔒' : ''), color: a.color };
        let v = map.get(r.video_id);
        if (!v) { v = { id: r.video_id, title: '', count: 0, people: new Map(), lastAt: at, latest: { who, text: r.text }, lastOther: 0 }; map.set(r.video_id, v); }
        if (!v.title && r.video_title) v.title = cleanTitle(r.video_title);
        v.count++;
        const pk = a.hidden ? 'anon' : r.user_id;
        if (!v.people.has(pk)) v.people.set(pk, who);
        if (!(u && r.user_id === u.id)) v.lastOther = Math.max(v.lastOther, at);
      });
      const vids = [...map.values()].slice(0, 30);
      if (!vids.length) { list.innerHTML = '<div class="empty">No danmu yet. Paste a link above and write the first one!</div>'; return; }
      list.innerHTML = vids.map(v => {
        const people = [...v.people.values()];
        const names = people.slice(0, 3).map(p => '<span style="color:' + esc(p.color) + '">' + esc(p.name) + '</span>').join(', ') + (people.length > 3 ? ' +' + (people.length - 3) : '');
        return '<a class="feed-item" href="?v=' + v.id + '" data-id="' + v.id + '">' +
          '<span class="thumb"><img src="https://i.ytimg.com/vi/' + v.id + '/mqdefault.jpg" alt="" loading="lazy">' +
            (v.lastOther > feedSeen ? '<span class="new">NEW</span>' : '') + '</span>' +
          '<span class="info"><span class="vtitle">' + esc(v.title || 'YouTube video') + '</span>' +
          '<span class="meta">💬 ' + v.count + ' · ' + names + ' · ' + timeAgo(v.lastAt) + '</span>' +
          '<span class="last"><b style="color:' + esc(v.latest.who.color) + '">' + esc(v.latest.who.name) + ':</b> ' + esc(v.latest.text) + '</span></span></a>';
      }).join('');
      list.querySelectorAll('.feed-item').forEach(a => a.onclick = e => { e.preventDefault(); go({ id: a.dataset.id, short: false, t: 0 }); });
      const newest = vids.reduce((m, v) => Math.max(m, v.lastAt), 0);
      if (newest > feedSeen) { feedSeen = newest; lsSet(SEEN_KEY, feedSeen); }   // badges shown now, cleared next visit
    } catch (e) {
      list.innerHTML = '<div class="empty">⚠ Could not load: ' + esc(e.message) + '</div>';
    }
  }

  // ── WATCH ──────────────────────────────────────────────────────────────────
  function showWatch(p) {
    $('home').classList.add('hidden'); $('watch').classList.remove('hidden');
    document.body.classList.add('watching');
    const changed = p.id !== videoId;
    videoId = p.id; isShort = !!p.short; startAt = p.t || 0;
    $('stage').classList.toggle('short', isShort);
    $('stage-msg').classList.add('hidden');
    if (changed) {
      rows = []; pending.clear(); lastSec = -1; clearDanmu(); cancelEdit();
      $('video-title').textContent = '';
      renderList();
    }
    loadPlayer();
    loadDanmu(true);
    clearInterval(pollTimer);
    pollTimer = setInterval(() => { if (document.visibilityState === 'visible') loadDanmu(false); }, POLL_MS);
    clearInterval(tickTimer);
    tickTimer = setInterval(tick, 200);
    updateComposer();
  }

  function stopWatch() {
    clearInterval(pollTimer); clearInterval(tickTimer);
    if (playerReady) try { player.pauseVideo(); } catch { /* not ready */ }
    clearDanmu(); exitFs();
  }

  // YouTube IFrame Player API
  function loadPlayer() {
    if (!apiReady) {
      if (!document.getElementById('yt-api')) {
        window.onYouTubeIframeAPIReady = () => { apiReady = true; loadPlayer(); };
        const s = document.createElement('script');
        s.id = 'yt-api'; s.src = 'https://www.youtube.com/iframe_api';
        s.onerror = () => showStageMsg('Could not load the YouTube player. Check your connection.');
        document.head.appendChild(s);
      }
      return;
    }
    if (player && playerReady) {
      if (player.getVideoData?.().video_id !== videoId) player.loadVideoById({ videoId, startSeconds: startAt });
      return;
    }
    if (player) return;   // still creating
    player = new YT.Player('yt-player', {
      videoId,
      playerVars: { playsinline: 1, rel: 0, fs: 0, modestbranding: 1, start: startAt, origin: location.origin },
      events: {
        onReady: () => {
          playerReady = true;
          if (player.getVideoData?.().video_id !== videoId) player.loadVideoById({ videoId, startSeconds: startAt });
          updateTitle();
        },
        onStateChange: e => {
          if (e.data === 1) { live.forEach(a => a.play()); updateTitle(); }       // playing
          else if (e.data === 2 || e.data === 3) live.forEach(a => a.pause());    // paused / buffering
        },
        onError: e => {
          const blocked = e.data === 101 || e.data === 150 || e.data === 153;
          showStageMsg(blocked
            ? 'The owner of this video doesn\'t allow it to play on other sites. <a href="https://www.youtube.com/watch?v=' + videoId + '" target="_blank" rel="noopener">Open in YouTube</a> (danmu can\'t show there).'
            : 'This video can\'t be played (error ' + e.data + ').');
        }
      }
    });
  }
  function showStageMsg(html) { const m = $('stage-msg'); m.innerHTML = html; m.classList.remove('hidden'); }
  function updateTitle() {
    try {
      const t = player.getVideoData().title;
      if (t) { $('video-title').textContent = t; document.title = t + ' · VideoIQ Danmu'; }
    } catch { /* not ready */ }
  }
  const nowSec = () => { try { return playerReady ? player.getCurrentTime() || 0 : startAt; } catch { return 0; } };

  function tick() {
    if (!playerReady) return;
    const t = Math.floor(nowSec());
    $('time-hint').textContent = editing ? '✏️ Editing your danmu at ' + fmt(editing.time_sec) + ': change text and/or 🎨 style' : '⏱ Will be added at ' + fmt(t);
    if (t === lastSec) return;
    const jumped = lastSec >= 0 && Math.abs(t - lastSec) > 2;
    lastSec = t;
    let state = -1; try { state = player.getPlayerState(); } catch { /* */ }
    if (!jumped && state === 1 && danmuOn) rows.forEach(r => { if (r.time_sec === t && !r.is_summary) launch(r); });
    highlightNow(t);
  }

  // ── Danmu data ─────────────────────────────────────────────────────────────
  async function loadDanmu(first) {
    if (!C.isConfigured() || !videoId) return;
    const vid = videoId;
    try {
      const got = (await C.getVideo(vid)) || [];
      if (vid !== videoId) return;
      const ids = new Set(got.map(r => r.user_id + ':' + r.client_id));
      pending.forEach((r, k) => { if (!ids.has(r.user_id + ':' + k)) got.push(r); });
      rows = got.sort((a, b) => a.time_sec - b.time_sec);
      renderList();
      if (first) lastSec = -1;   // show danmu of the current second too
    } catch (e) {
      if (first) toast('⚠ Could not load danmu: ' + e.message, 4000);
    }
  }

  // ── Floating danmu ─────────────────────────────────────────────────────────
  function clearDanmu() { live.forEach(a => a.cancel()); live.clear(); $('overlay').innerHTML = ''; lanes.top = []; lanes.bottom = []; }

  function launch(r, now) {   // now = show right away even if paused (your own new danmu)
    const overlay = $('overlay');
    const W = overlay.clientWidth, H = overlay.clientHeight;
    if (!W || !H) return;
    const st = Object.assign({}, DEFAULT_STYLE, r.style || {});
    const font = FONTS.find(f => f.id === st.font) || FONTS[0];
    const scale = clamp(W / 640, 0.82, 1.25);       // phones slightly smaller (still readable), big screens bigger
    const px = Math.round(((SIZES.find(z => z.id === st.size) || SIZES[1]).px) * scale);
    const mode = MODES.some(m => m.id === st.mode) ? st.mode : 'rtl';
    const dur = clamp(Number(st.duration) || 5, 1, 60) * 1000;
    const a = author(r);
    const u = me();

    const el = document.createElement('div');
    el.className = 'dm ' + mode + (u && r.user_id === u.id ? ' mine' : '');
    // name shows if the viewer wants names AND the writer didn't hide it from this viewer
    const showName = showNames && !a.hidden && !a.mineAnon;
    el.textContent = (showName ? '[' + a.name + (a.revealed ? ' 🔒' : '') + '] ' : '') + r.text;
    el.style.color = st.color || r.profiles?.color || '#ffffff';
    el.style.fontFamily = font.css + ',' + EMOJI_FALLBACK;
    el.style.fontSize = px + 'px';
    overlay.appendChild(el);

    let anim;
    if (mode === 'top' || mode === 'bottom') {
      const laneH = Math.round(px * 1.5), maxL = Math.max(1, Math.floor(H * 0.42 / laneH)), now = Date.now();
      const L = lanes[mode];
      let i = L.findIndex((until, k) => k < maxL && until <= now);
      if (i === -1) i = L.length < maxL ? L.length : L.indexOf(Math.min(...L.slice(0, maxL)));
      L[i] = now + dur;
      el.style[mode] = (6 + i * laneH) + 'px';
      if (el.offsetWidth > W * 0.92) el.style.fontSize = Math.max(10, Math.floor(px * W * 0.92 / el.offsetWidth)) + 'px';
      anim = el.animate([{ opacity: 0 }, { opacity: 1, offset: 0.04 }, { opacity: 1, offset: 0.92 }, { opacity: 0 }],
                        { duration: dur, easing: 'linear', fill: 'forwards' });
    } else {
      el.style.top = Math.round(6 + Math.random() * Math.max(1, H * 0.72 - px)) + 'px';
      const dist = W + el.offsetWidth;
      anim = el.animate([{ transform: 'translateX(0)' }, { transform: 'translateX(' + (mode === 'rtl' ? -dist : dist) + 'px)' }],
                        { duration: SCROLL_MS, easing: 'linear', fill: 'forwards' });
    }
    live.add(anim);
    anim.onfinish = () => { live.delete(anim); el.remove(); };
    try { if (!now && player.getPlayerState() !== 1) anim.pause(); } catch { /* */ }
  }

  $('danmu-toggle').onclick = () => {
    danmuOn = !danmuOn; lsSet(DANMU_ON_KEY, danmuOn);
    $('overlay').classList.toggle('off', !danmuOn);
    $('danmu-toggle').classList.toggle('off', !danmuOn);
  };
  $('overlay').classList.toggle('off', !danmuOn);
  $('danmu-toggle').classList.toggle('off', !danmuOn);

  $('names-toggle').onclick = () => {
    showNames = !showNames; lsSet(NAMES_KEY, showNames);
    $('names-toggle').classList.toggle('off', !showNames);
    toast(showNames ? 'Names shown on danmu' : 'Names hidden: only the danmu text shows');
  };
  $('names-toggle').classList.toggle('off', !showNames);

  // Our own full screen: on iPhone the player's native full screen would hide the danmu
  $('fs-btn').onclick = () => document.body.classList.contains('fs') ? exitFs() : enterFs();
  function enterFs() {
    document.body.classList.add('fs'); $('fs-btn').textContent = '✕';
    const el = document.documentElement;
    if (el.requestFullscreen && !/iPhone|iPod/.test(navigator.userAgent)) el.requestFullscreen().catch(() => {});
    try { screen.orientation?.lock?.('landscape').catch(() => {}); } catch { /* not supported */ }
    clearDanmu();
  }
  function exitFs() {
    if (!document.body.classList.contains('fs')) return;
    document.body.classList.remove('fs'); $('fs-btn').textContent = '⛶';
    if (document.fullscreenElement) document.exitFullscreen().catch(() => {});
    clearDanmu();
  }
  document.addEventListener('fullscreenchange', () => { if (!document.fullscreenElement && document.body.classList.contains('fs')) exitFs(); });

  // ── Style (remembered on this device) ──────────────────────────────────────
  let style = Object.assign({}, DEFAULT_STYLE, lsGet(STYLE_KEY, {}));
  // While editing a danmu, the style bar shows and changes THAT danmu's style (editStyle);
  // otherwise it's your default for new danmu (style, remembered on this device).
  let editStyle = null;
  const baseStyle = () => editing && editStyle ? editStyle : style;
  const curStyle = () => { const b = baseStyle(); return Object.assign({}, b, { color: b.color || me()?.color || '#4f9eff' }); };
  function fillSelect(sel, list, cur, label) {
    sel.innerHTML = list.map(o => '<option value="' + esc(o.id ?? o) + '"' + (String(o.id ?? o) === String(cur) ? ' selected' : '') + '>' + esc(label(o)) + '</option>').join('');
  }
  function buildStyleBar() {
    const s = curStyle();
    fillSelect($('st-font'), FONTS, s.font, o => o.label);
    fillSelect($('st-size'), SIZES, s.size, o => o.label);
    fillSelect($('st-mode'), MODES, s.mode, o => o.label);
    fillSelect($('st-dur'), DURATIONS, s.duration, d => d + 's');
    $('st-color').value = s.color;
    updateStyleUI();
    updateNameVis();
  }
  function updateStyleUI() {
    const s = curStyle();
    $('st-dur').classList.toggle('hidden', s.mode !== 'top' && s.mode !== 'bottom');
    const smp = $('st-sample');
    smp.style.color = s.color;
    smp.style.fontFamily = (FONTS.find(f => f.id === s.font) || FONTS[0]).css + ',' + EMOJI_FALLBACK;
    smp.style.fontSize = Math.min((SIZES.find(z => z.id === s.size) || SIZES[1]).px, 24) + 'px';
  }
  ['st-font', 'st-size', 'st-mode', 'st-dur', 'st-color'].forEach(id => $(id).addEventListener(id === 'st-color' ? 'input' : 'change', () => {
    const next = { font: $('st-font').value, size: $('st-size').value, color: $('st-color').value,
                   mode: $('st-mode').value, duration: +$('st-dur').value || 5,
                   anon: !!baseStyle().anon, nameTo: baseStyle().nameTo || null };
    if (editing) editStyle = next;               // saved with the danmu when you tap Save
    else { style = next; lsSet(STYLE_KEY, style); }
    updateStyleUI();
  }));
  $('style-btn').onclick = () => $('style-bar').classList.toggle('hidden');
  // Who can see my name: everyone / nobody / only one person
  $('st-namevis').onchange = async () => {
    const v = $('st-namevis').value;
    let patch;
    if (v === 'all') patch = { anon: false, nameTo: null };
    else if (v === 'none') patch = { anon: true, nameTo: null };
    else {
      try {
        if (!(await C.privacyReady())) throw new Error('This needs a database update (privacy.sql). Ask the owner to run it');
        const who = prompt('Show your name only to… (type their display name)', baseStyle().nameTo?.name || '');
        if (who === null) { updateNameVis(); return; }
        patch = { anon: true, nameTo: await C.findUser(who) };
      } catch (e) { toast('❌ ' + e.message, 4000); updateNameVis(); return; }
    }
    const later = editing ? ' (tap Save)' : '';
    if (editing) editStyle = Object.assign({}, editStyle, patch);
    else { style = Object.assign({}, style, patch); lsSet(STYLE_KEY, style); }
    updateNameVis();
    toast(!patch.anon ? '👤 Everyone will see your name' + later
        : patch.nameTo ? '🔒 Only ' + patch.nameTo.name + ' will see your name' + later
        : '🙈 Nobody will see your name' + later);
  };
  function updateNameVis() {
    const s = baseStyle(), sel = $('st-namevis');
    sel.value = !s.anon ? 'all' : s.nameTo ? 'one' : 'none';
    sel.options[2].textContent = s.anon && s.nameTo ? '🔒 Name: only ' + s.nameTo.name : '🔒 Name: only one person…';
    sel.classList.toggle('private', !!s.anon);
  }
  $('app-ver').textContent = APP_VERSION;

  // Emoji
  $('emoji-grid').innerHTML = EMOJIS.map(e => '<button type="button">' + e + '</button>').join('');
  $('emoji-btn').onclick = () => { if (!C.isSignedIn()) return openSheet(); $('emoji-grid').classList.toggle('hidden'); };
  $('emoji-grid').querySelectorAll('button').forEach(b => {
    b.onmousedown = e => e.preventDefault();
    b.onclick = () => {
      const inp = $('danmu-input'), a = inp.selectionStart ?? inp.value.length, z = inp.selectionEnd ?? inp.value.length;
      if (inp.value.length - (z - a) + b.textContent.length > 500) return;
      inp.value = inp.value.slice(0, a) + b.textContent + inp.value.slice(z);
      inp.setSelectionRange(a + b.textContent.length, a + b.textContent.length);
    };
  });

  // ── Write / edit / delete ──────────────────────────────────────────────────
  function updateComposer() {
    const signed = C.isSignedIn();
    $('signin-note').classList.toggle('hidden', signed);
    // signed out: the line stays visible; tapping it (or Send / 😊) opens sign-in
    $('danmu-input').readOnly = !signed;
    $('danmu-input').placeholder = signed ? 'Write a danmu at this moment…' : '👤 Sign in to write danmu';
    $('fs-input').placeholder = signed ? 'Danmu…' : 'Sign in to write';
    $('fs-input').disabled = !signed;
  }
  $('signin-to-write').onclick = () => openSheet();
  $('danmu-input').addEventListener('click', () => { if (!C.isSignedIn()) openSheet(); });

  // ── Phone layout: video fills the screen, one input line pinned to the bottom ──
  const compactMQ = matchMedia('(max-width: 820px), (pointer: coarse)');
  function applyCompact() { document.body.classList.toggle('compact', compactMQ.matches); measureBar(); }
  (compactMQ.addEventListener ? compactMQ.addEventListener('change', applyCompact) : compactMQ.addListener(applyCompact));
  function setDrawer(open) {
    $('drawer').classList.toggle('open', open);
    $('more-btn').textContent = open ? '⌄' : '⌃';
    $('more-btn').title = open ? 'Close' : 'Style, danmu list and more';
    if (open) $('style-bar').classList.remove('hidden');
    measureBar();
  }
  $('more-btn').onclick = () => setDrawer(!$('drawer').classList.contains('open'));
  $('back-btn').onclick = () => { history.pushState(null, '', location.pathname); showHome(); };
  $('acc-mini').onclick = () => openSheet();
  // The video ends where the collapsed bar begins (the open panel floats over the video)
  function measureBar() {
    const d = $('drawer');
    if (!document.body.classList.contains('compact') || d.classList.contains('open')) return;
    document.documentElement.style.setProperty('--bar-h', d.offsetHeight + 'px');
  }
  if (window.ResizeObserver) new ResizeObserver(measureBar).observe($('drawer'));
  // iPhone keyboard: keep the input line just above it
  if (window.visualViewport) {
    const kb = () => {
      const v = window.visualViewport;
      const gap = Math.max(0, Math.round(window.innerHeight - v.height - v.offsetTop));
      document.documentElement.style.setProperty('--kb', gap + 'px');
    };
    visualViewport.addEventListener('resize', kb); visualViewport.addEventListener('scroll', kb);
  }
  applyCompact();
  $('send-btn').onclick = () => send($('danmu-input'));
  $('danmu-input').onkeydown = e => { if (e.key === 'Enter' && !composing(e)) { e.preventDefault(); send($('danmu-input')); } if (e.key === 'Escape') cancelEdit(); };
  $('fs-send').onclick = () => send($('fs-input'));
  $('fs-input').onkeydown = e => { if (e.key === 'Enter' && !composing(e)) { e.preventDefault(); send($('fs-input')); } };
  $('cancel-edit').onclick = cancelEdit;

  async function send(inp) {
    const text = inp.value.trim();
    if (!text) return;
    const u = me(); if (!u) { openSheet(); return; }
    if (editing) return saveEdit(text);
    const row = {
      user_id: u.id, client_id: Date.now(), time_sec: Math.floor(nowSec()), text, style: curStyle(), is_summary: false,
      profiles: { display_name: u.name, color: u.color }
    };
    const nameTo = row.style.anon ? row.style.nameTo : null;
    row.name_to = nameTo ? [nameTo] : [];
    pending.set(row.client_id, row);
    rows.push(row); rows.sort((a, b) => a.time_sec - b.time_sec);
    inp.value = ''; $('emoji-grid').classList.add('hidden');
    if (danmuOn) launch(row, true);
    renderList();
    try {
      await C.upsert(videoId, $('video-title').textContent, [{ id: row.client_id, time: row.time_sec, text, style: row.style, isSummary: false, nameTo }]);
      pending.delete(row.client_id);
      toast('☁ Saved');
    } catch (e) {
      pending.delete(row.client_id);
      rows = rows.filter(r => r !== row); renderList();
      inp.value = text;
      toast('❌ Not saved: ' + e.message, 4000);
    }
  }

  function startEdit(r) {
    editing = r;
    editStyle = Object.assign({}, DEFAULT_STYLE, { color: r.profiles?.color || null }, r.style || {},
                              { nameTo: (r.name_to || [])[0] || null });
    buildStyleBar();                               // show this danmu's current style
    $('style-bar').classList.remove('hidden');
    if (document.body.classList.contains('compact')) setDrawer(true);
    $('danmu-input').value = r.text; $('danmu-input').focus();
    $('send-btn').textContent = 'Save'; $('cancel-edit').hidden = false;
    $('compose').classList.add('editing');
    $('compose').scrollIntoView({ behavior: 'smooth', block: 'center' });
  }
  function cancelEdit() {
    const wasEditing = !!editing;
    editing = null; editStyle = null;
    if (wasEditing) buildStyleBar();               // back to your default style
    $('send-btn').textContent = 'Send'; $('cancel-edit').hidden = true;
    $('compose').classList.remove('editing');
    if ($('danmu-input')) $('danmu-input').value = '';
  }
  async function saveEdit(text) {
    const r = editing, old = { text: r.text, style: r.style, name_to: r.name_to };
    const newStyle = curStyle(), nameTo = newStyle.anon ? newStyle.nameTo : null;
    r.text = text; r.style = newStyle; r.name_to = nameTo ? [nameTo] : [];
    cancelEdit(); renderList();
    if (danmuOn) launch(r, true);                  // show how it looks now
    try {
      await C.upsert(videoId, $('video-title').textContent, [{ id: r.client_id, time: r.time_sec, text, style: newStyle, isSummary: r.is_summary, nameTo }]);
      toast('☁ Updated');
    } catch (e) { r.text = old.text; r.style = old.style; r.name_to = old.name_to; renderList(); toast('❌ Not saved: ' + e.message, 4000); }
  }
  async function del(r) {
    if (!confirm('Delete this danmu?\n\n' + r.text)) return;
    rows = rows.filter(x => x !== r); renderList();
    try { await C.remove([r.client_id]); toast('Deleted'); }
    catch (e) { rows.push(r); rows.sort((a, b) => a.time_sec - b.time_sec); renderList(); toast('❌ Not deleted: ' + e.message, 4000); }
  }
  function reply(r) {
    const u = me(); if (!u) { openSheet(); return; }
    try { player.seekTo(r.time_sec, true); player.pauseVideo(); } catch { /* */ }
    cancelEdit();
    const inp = $('danmu-input');
    inp.value = '@' + (r.profiles?.display_name || '') + ' ';
    inp.focus(); inp.setSelectionRange(inp.value.length, inp.value.length);
  }

  // ── List ───────────────────────────────────────────────────────────────────
  document.querySelectorAll('.chip').forEach(c => c.onclick = () => {
    document.querySelectorAll('.chip').forEach(x => x.classList.toggle('active', x === c));
    filter = c.dataset.f; renderList();
  });

  function renderList() {
    const u = me(), list = $('danmu-list');
    let items = rows;
    if (filter === 'mine')   items = rows.filter(r => u && r.user_id === u.id);
    if (filter === 'others') items = rows.filter(r => !(u && r.user_id === u.id));
    const people = new Set(rows.map(r => r.user_id)).size;
    $('list-title').textContent = rows.length ? '💬 ' + rows.length + ' danmu · ' + people + (people === 1 ? ' person' : ' people') : 'Danmu';
    if (!items.length) {
      list.innerHTML = '<div class="empty">' + (rows.length ? 'Nothing here.' : 'No danmu on this video yet — be the first!') + '</div>';
      return;
    }
    const mention = u ? new RegExp('@' + escRe(u.name) + '(?![\\w])', 'i') : null;
    list.innerHTML = items.map((r, i) => {
      const mine = u && r.user_id === u.id;
      const a = author(r);
      const cls = 'row' + (mention && !mine && mention.test(r.text) ? ' mention' : '');
      return '<div class="' + cls + '" data-i="' + i + '" data-t="' + r.time_sec + '">' +
        '<span class="t">' + fmt(r.time_sec) + '</span>' +
        '<span class="body"><span class="who" style="color:' + esc(a.color) + '"' + (a.tip ? ' title="' + esc(a.tip) + '"' : '') + '>' + esc(a.name) +
          (a.note ? '<span class="lock">' + esc(a.note) + '</span>' : '') + '</span>' + esc(r.text) + '</span>' +
        '<span class="acts">' + (mine
          ? '<button data-a="edit" title="Edit">✎</button><button data-a="del" title="Delete">✕</button>'
          : a.hidden ? '' : '<button data-a="reply" title="Reply">↩</button>') + '</span></div>';
    }).join('');
    list.querySelectorAll('.row').forEach(el => {
      const r = items[+el.dataset.i];
      el.querySelector('.t').onclick = () => { try { player.seekTo(r.time_sec, true); player.playVideo(); } catch { /* */ } };
      el.querySelectorAll('button').forEach(b => b.onclick = () => ({ edit: startEdit, del, reply })[b.dataset.a](r));
    });
    highlightNow(lastSec);
  }
  function highlightNow(t) {
    document.querySelectorAll('#danmu-list .row').forEach(el => el.classList.toggle('now', Math.abs(+el.dataset.t - t) <= 1));
  }

  // ── Account ────────────────────────────────────────────────────────────────
  function updatePill() {
    const u = me();
    $('account-pill').innerHTML = u ? '<span class="dot"></span>' + esc(u.name) : '👤 Sign in';
  }
  $('account-pill').onclick = () => openSheet();
  $('sheet-close').onclick = closeSheet;
  $('sheet-bg').onclick = e => { if (e.target === $('sheet-bg')) closeSheet(); };
  function closeSheet() { $('sheet-bg').classList.add('hidden'); }

  function openSheet() {
    $('sheet-bg').classList.remove('hidden');
    const body = $('sheet-body'), u = me();
    if (!C.isConfigured()) { body.innerHTML = '<p class="note">Online saving is not set up.</p>'; return; }
    if (u) {
      body.innerHTML =
        '<p class="note ok">Signed in as <b style="color:' + esc(u.color) + '">' + esc(u.name) + '</b><br>' + esc(u.email) + '</p>' +
        '<p class="note">This is the same account as the VideoIQ Chrome extension. Your danmu are shared everywhere.</p>' +
        '<button class="ghost" id="acc-out">Sign out</button>';
      $('acc-out').onclick = async () => { await C.signOut(); closeSheet(); };
      return;
    }
    body.innerHTML =
      '<div class="tabs"><button class="active" data-m="in">Sign in</button><button data-m="up">Create account</button></div>' +
      '<input id="acc-name" class="hidden" type="text" maxlength="30" placeholder="Display name (everyone sees this)" autocomplete="nickname">' +
      '<input id="acc-email" type="email" placeholder="Email" autocomplete="email" autocapitalize="off">' +
      '<input id="acc-pass" type="password" placeholder="Password" autocomplete="current-password">' +
      '<input id="acc-code" class="hidden" type="text" inputmode="numeric" autocomplete="one-time-code" placeholder="Code from the email" maxlength="12">' +
      '<button class="primary" id="acc-go">Sign in</button>' +
      '<button class="ghost hidden" id="acc-resend">Send a new code</button>' +
      '<p class="note" id="acc-msg"></p>';
    let mode = 'in';
    const note = (t, cls) => { $('acc-msg').textContent = t; $('acc-msg').className = 'note' + (cls ? ' ' + cls : ''); };
    const setMode = m => {
      mode = m;
      body.querySelectorAll('.tabs button').forEach(b => b.classList.toggle('active', b.dataset.m === m));
      $('acc-name').classList.toggle('hidden', m !== 'up');
      $('acc-pass').classList.toggle('hidden', m === 'code');
      $('acc-code').classList.toggle('hidden', m !== 'code');
      $('acc-resend').classList.toggle('hidden', m !== 'code');
      $('acc-pass').autocomplete = m === 'up' ? 'new-password' : 'current-password';
      $('acc-pass').placeholder = m === 'up' ? 'Password (at least 6 characters)' : 'Password';
      $('acc-go').textContent = { in: 'Sign in', up: 'Create account', code: 'Confirm' }[m];
      note('');
    };
    body.querySelectorAll('.tabs button').forEach(b => b.onclick = () => setMode(b.dataset.m));
    body.querySelectorAll('input').forEach(i => i.onkeydown = e => { if (e.key === 'Enter' && !composing(e)) $('acc-go').click(); });
    $('acc-resend').onclick = async () => {
      try { await C.resendCode($('acc-email').value); note('✓ New code sent. Check your email (and spam).', 'ok'); }
      catch (e) { note('❌ ' + e.message, 'err'); }
    };
    $('acc-go').onclick = async () => {
      const email = $('acc-email').value.trim(), pass = $('acc-pass').value, btn = $('acc-go');
      if (!email || (mode !== 'code' && !pass)) { note('Enter your email and password', 'err'); return; }
      btn.disabled = true; note(mode === 'up' ? 'Creating account…' : mode === 'code' ? 'Confirming…' : 'Signing in…');
      try {
        if (mode === 'code') await C.verifyEmailCode({ email, code: $('acc-code').value });
        else if (mode === 'up') {
          const r = await C.signUp({ email, password: pass, name: $('acc-name').value, color: style.color || '#4f9eff' });
          if (!r.signedIn) { setMode('code'); note('✓ Account created! Enter the code we emailed you (check spam too).', 'ok'); }
        } else await C.signIn({ email, password: pass });
      } catch (e) {
        if (/confirm your email/i.test(e.message)) { setMode('code'); note('Your email isn\'t confirmed yet. Enter the code from the email, or tap "Send a new code".', 'ok'); }
        else note('❌ ' + e.message, 'err');
      }
      btn.disabled = false;
    };
  }

  C.onChange(u => {
    updatePill(); updateComposer(); renderList(); buildStyleBar();
    // who may see which names depends on who you are → reload with the new account
    if (videoId && !$('watch').classList.contains('hidden')) loadDanmu(false); else if (!$('home').classList.contains('hidden')) loadFeed();
    if (u) { closeSheet(); toast('👋 Signed in as ' + u.name); }
  });

  // ── Installable app (Android: appears in the YouTube app's Share menu) ─────
  if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => { /* optional */ });
  let installPrompt = null;
  window.addEventListener('beforeinstallprompt', e => {
    e.preventDefault(); installPrompt = e;
    $('install-wrap').hidden = false;
  });
  $('install-btn').onclick = async () => {
    if (!installPrompt) return;
    installPrompt.prompt();
    const r = await installPrompt.userChoice.catch(() => null);
    if (r && r.outcome === 'accepted') { $('install-wrap').hidden = true; toast('✓ Installed. Find VideoIQ in the YouTube app\'s Share menu'); }
    installPrompt = null;
  };

  // ── Start ──────────────────────────────────────────────────────────────────
  window.addEventListener('popstate', route);
  (async () => {
    buildStyleBar();
    if (C.isConfigured()) await C.init();
    updatePill(); updateComposer(); buildStyleBar();
    route();
  })();
})();
