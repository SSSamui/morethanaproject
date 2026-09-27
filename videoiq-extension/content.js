// VideoIQ Danmu — content.js  v9
// Local-first. No account needed. Optionally post publicly with a name.
(function () {
  'use strict';

  const LOCAL_KEY    = 'videoiq_danmu';
  const SETTINGS_KEY = 'videoiq_settings';

  let settings = {
    username: 'Me', color: '#4f9eff',
    showOwn: true, showOnVideo: true, showNames: true,
    panelX: null, panelY: null, minimized: false,
    defaultPublic: true,
    // Danmu style — remembered until the user changes it again
    danmuStyle: null
  };

  // ── DANMU STYLE OPTIONS ──────────────────────────────────────────────────────
  const EMOJI_FALLBACK = '"Segoe UI Emoji","Apple Color Emoji","Noto Color Emoji",sans-serif';
  const FONTS = [
    { id: 'default', label: 'Default',   css: "-apple-system,BlinkMacSystemFont,'Segoe UI',system-ui" },
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
  // anon: the WRITER hides their name on this danmu for everyone
  const DEFAULT_STYLE = { font: 'default', size: 'm', color: null, mode: 'rtl', duration: 5, anon: false };
  const ANON_NAME = '🙈 Anonymous', ANON_COLOR = '#9ca3af';

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

  // Other people's danmu on this video, one entry per person:
  // [{id, author_name, color, notes:[{id,time,text,style,isSummary}], _source}]
  let remoteList = [];
  function remoteAuthors() { return remoteList; }

  // Online sync state
  const DEL_KEY  = 'videoiq_pending_deletes';
  const POLL_MS  = 10000;
  let pendingDeletes = {};      // { videoId: [clientId…] } deleted locally, not yet deleted online
  let syncTimer = null, pollTimer = null, syncing = false;
  const cloudOn  = () => !!window.VIQ_CLOUD?.isConfigured();
  const signedIn = () => !!window.VIQ_CLOUD?.isSignedIn();

  // ── BOOT ─────────────────────────────────────────────────────────────────────
  function boot() {
    chrome.storage.local.get([LOCAL_KEY, SETTINGS_KEY], async (res) => {
      localNotes = res[LOCAL_KEY] || {};
      settings   = Object.assign(settings, res[SETTINGS_KEY] || {});
      pendingDeletes = (await new Promise(r => chrome.storage.local.get([DEL_KEY], x => r(x[DEL_KEY])))) || {};
      if (cloudOn()) {
        const user = await VIQ_CLOUD.init();
        if (user) adoptAccount(user);
        VIQ_CLOUD.onChange(onAccountChange);
      }
      startRouting();
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
  let waiting = false;
  function waitForVideo() {
    if (waiting) return;
    waiting = true;
    let n = 0;
    const t = setInterval(() => {
      n++;
      videoEl = findActiveVideo();
      const id = getVideoId();
      if (videoEl && id) {
        clearInterval(t); waiting = false;
        videoId = id;
        rebuildActive();
        if (!sidePanel) buildUI();
        startLoop();
        watchNavigation();
        loadRemote();
        startPolling();
      }
      if (n > 50) { clearInterval(t); waiting = false; }
    }, 600);
  }

  // ── ROUTING ──────────────────────────────────────────────────────────────────
  // YouTube is a single-page app: the script loads once on any youtube.com page,
  // then pages change without reloading. Video pages get the danmu panel;
  // every other page (home, search, channels…) gets the "New danmu" feed.
  let lastRoute = null, panelHiddenByUser = false, feedShownThisLoad = false;

  function startRouting() {
    buildFeedButton();
    onRoute();
    document.addEventListener('yt-navigate-finish', onRoute);
    setInterval(() => { if (location.href !== lastRoute) onRoute(); }, 1000);
    setInterval(() => { if (document.visibilityState === 'visible') refreshFeed(true); }, FEED_POLL_MS);
  }

  function onRoute() {
    lastRoute = location.href;
    const onVideo = !!getVideoId();
    if (onVideo) {
      if (!sidePanel) waitForVideo();
      setWatchUIVisible(true);
    } else {
      setWatchUIVisible(false);
      // Opening YouTube → show the newest danmu'd videos once per page load
      if (!feedShownThisLoad && settings.feedAutoOpen !== false && cloudOn()) { feedShownThisLoad = true; openFeed(); }
    }
    refreshFeed(true);
  }

  function setWatchUIVisible(on) {
    const tb = document.getElementById('viq-toggle-btn');
    if (tb) tb.style.display = on ? '' : 'none';
    if (sidePanel) sidePanel.style.display = on && !panelHiddenByUser ? 'flex' : 'none';
    if (danmuContainer) danmuContainer.style.display = on ? '' : 'none';
  }

  function setCloudBar(state, html) {
    const bar = document.getElementById('viq-cloud-bar'); if (!bar) return;
    bar.className = 'viq-cloud-bar viq-cloud-' + state;
    bar.innerHTML = html;
    bar.classList.toggle('hidden', state === 'hidden');
  }

  // ── ONLINE SYNC ──────────────────────────────────────────────────────────────
  // Load everyone's danmu for this video. Other people → remoteList (read-only).
  // Our own rows are reconciled with local notes (restores them on a new device,
  // uploads ones written offline / before signing in, applies edits made elsewhere).
  async function loadRemote(silent) {
    if (!cloudOn() || !videoId) return;
    const vid = videoId, started = Date.now();
    if (!silent) setCloudBar('loading', '☁ Loading danmu…');
    try {
      if (signedIn()) await pushDeletes();
      const rows = (await VIQ_CLOUD.getVideo(vid)) || [];
      if (vid !== videoId) return;
      const me = VIQ_CLOUD.getUser();
      // while signed out, don't show our own (already local) notes twice
      const localOwn = new Set((localNotes[vid] || []).filter(n => n.user === settings.username).map(n => Number(n.id)));
      const mine = [], byUser = new Map();
      rows.forEach(r => {
        if (me ? r.user_id === me.id : localOwn.has(Number(r.client_id))) { mine.push(r); return; }
        const anon = !!(r.style && r.style.anon);
        const key  = anon ? 'anon' : r.user_id;
        let a = byUser.get(key);
        if (!a) {
          const prev = remoteList.find(x => x.id === 'sb_' + key);
          a = { id: 'sb_' + key, author_name: anon ? ANON_NAME : (r.profiles?.display_name || 'Unknown'),
                color: prev?._recolored ? prev.color : (anon ? ANON_COLOR : (r.profiles?.color || '#a78bfa')),
                _recolored: prev?._recolored || undefined, notes: [], _source: 'sb', _anon: anon || undefined };
          byUser.set(key, a);
        }
        a.notes.push({ id: r.client_id, time: r.time_sec, text: r.text, style: r.style, isSummary: r.is_summary });
      });
      const next = [...byUser.values()];
      let changed = JSON.stringify(next) !== JSON.stringify(remoteList);
      remoteList = next;
      if (me) changed = reconcileOwn(vid, mine, started) || changed;
      if (changed) { rebuildActive(); refreshSideList(); buildUserSelector(); }
      if (!silent && changed) lastTime = -1;   // just loaded → show danmu for the current second too

      if (!silent) {
        const n = remoteList.reduce((t, p) => t + p.notes.length, 0);
        setCloudBar(remoteList.length ? 'loaded' : 'empty', remoteList.length
          ? '👥 ' + n + ' danmu from ' + remoteList.map(p => '<span style="color:' + escH(p.color) + '">' + escH(p.author_name) + '</span>').join(', ')
          : signedIn() ? '☁ No one else has danmu on this video yet'
                       : '☁ <b>Sign in</b> (⚙) to save your danmu online and share them');
        setTimeout(() => setCloudBar('hidden', ''), 4500);
      }
    } catch (e) {
      console.warn('VideoIQ load:', e.message);
      if (!silent) setCloudBar('error', '⚠ Could not load online danmu: ' + escH(e.message));
    }
  }

  function reconcileOwn(vid, rows, started) {
    const me = settings.username;
    if (!localNotes[vid]) localNotes[vid] = [];
    const list = localNotes[vid];
    const server = new Map(rows.map(r => [Number(r.client_id), r]));
    let changed = false, needPush = false;

    for (let i = list.length - 1; i >= 0; i--) {
      const n = list[i]; if (n.user !== me) continue;
      const r = server.get(Number(n.id));
      if (n._dirty || !n._synced) {
        needPush = true;                                   // new or edited here → upload
      } else if (!r) {
        if ((n._syncedAt || 0) < started) { list.splice(i, 1); changed = true; }   // deleted on another device
      } else if (r.text !== n.text || r.time_sec !== n.time ||
                 JSON.stringify(r.style || null) !== JSON.stringify(n.style || null)) {
        n.text = r.text; n.time = r.time_sec; n.ts = fmtTime(r.time_sec); n.style = r.style;   // edited elsewhere
        changed = true;
      }
    }
    const have = new Set(list.filter(n => n.user === me).map(n => Number(n.id)));
    const gone = new Set((pendingDeletes[vid] || []).map(Number));
    rows.forEach(r => {
      const id = Number(r.client_id);
      if (have.has(id) || gone.has(id)) return;
      list.push({ id, user: me, color: settings.color, text: r.text, time: r.time_sec, ts: fmtTime(r.time_sec),
                  isSummary: !!r.is_summary, style: r.style || null, videoId: vid,
                  _synced: true, _syncedAt: Date.now() });                             // written on another device
      changed = true;
    });
    if (changed) save();
    if (needPush) scheduleSync();
    return changed;
  }

  function startPolling() {
    clearInterval(pollTimer);
    pollTimer = setInterval(() => {
      if (document.visibilityState === 'visible') loadRemote(true);
    }, POLL_MS);
  }

  // A local change to one of our notes → upload shortly
  function markChanged(note) {
    note._dirty = true;
    note._rev = (note._rev || 0) + 1;
    save();
    scheduleSync();
  }

  function scheduleSync(delay) {
    if (!signedIn()) return;
    clearTimeout(syncTimer);
    syncTimer = setTimeout(pushAll, delay || 1200);
  }

  // Upload every unsynced note of ours (all videos) + pending deletes
  async function pushAll() {
    clearTimeout(syncTimer);
    if (!signedIn()) return;
    if (syncing) { scheduleSync(); return; }
    syncing = true;
    let uploaded = 0;
    try {
      await pushDeletes();
      const me = settings.username;
      for (const vid in localNotes) {
        const todo = (localNotes[vid] || []).filter(n => n.user === me && (n._dirty || !n._synced));
        if (!todo.length) continue;
        const revs = todo.map(n => n._rev || 0), stamp = Date.now();
        await VIQ_CLOUD.upsert(vid, vid === videoId ? pageTitle() : '', todo);
        todo.forEach((n, i) => {
          n._synced = true; n._syncedAt = stamp;
          if ((n._rev || 0) === revs[i]) n._dirty = false;   // edited again during upload → stays dirty
        });
        uploaded += todo.length;
      }
      save();
      if (uploaded) flashHint('☁ Saved online');
    } catch (e) {
      console.warn('VideoIQ save:', e);
      flashHint('❌ Online save failed: ' + e.message + ' (will retry)');
      scheduleSync(20000);
    } finally { syncing = false; }
  }

  async function pushDeletes() {
    const vids = Object.keys(pendingDeletes);
    if (!vids.length || !signedIn()) return;
    for (const vid of vids) {
      const ids = pendingDeletes[vid] || [];
      if (ids.length) await VIQ_CLOUD.remove(ids);
      delete pendingDeletes[vid];
    }
    chrome.storage.local.set({ [DEL_KEY]: pendingDeletes });
  }

  // ── NEW DANMU FEED ───────────────────────────────────────────────────────────
  // Videos that recently got danmu from anyone, newest first. "NEW" = activity by
  // someone else since you last opened the feed.
  const FEED_SEEN_KEY = 'videoiq_feed_seen';
  const FEED_POLL_MS  = 60000;
  let feedVideos = [], feedSeen = 0, feedLoading = false, feedError = '';

  function buildFeedButton() {
    if (!cloudOn() || document.getElementById('viq-feed-btn')) return;
    chrome.storage.local.get([FEED_SEEN_KEY], r => { feedSeen = r[FEED_SEEN_KEY] || 0; updateFeedBadge(); });
    const btn = document.createElement('button');
    btn.id = 'viq-feed-btn'; btn.title = 'New danmu on YouTube';
    btn.innerHTML = '🔥<span class="viq-feed-badge hidden" id="viq-feed-badge"></span>';
    btn.onclick = () => document.getElementById('viq-feed')?.classList.contains('open') ? closeFeed() : openFeed();
    document.body.appendChild(btn);

    const feed = document.createElement('div');
    feed.id = 'viq-feed';
    feed.innerHTML = `
      <div class="viq-feed-head">
        <span class="viq-feed-title">🔥 New danmu</span>
        <button class="viq-icon-btn" id="viq-feed-refresh" title="Refresh">⟳</button>
        <button class="viq-icon-btn" id="viq-feed-close" title="Close">✕</button>
      </div>
      <div class="viq-feed-list" id="viq-feed-list"></div>
      <label class="viq-feed-foot"><input type="checkbox" id="viq-feed-auto" ${settings.feedAutoOpen !== false ? 'checked' : ''}/> Show when I open YouTube</label>`;
    document.body.appendChild(feed);
    document.getElementById('viq-feed-close').onclick = closeFeed;
    document.getElementById('viq-feed-refresh').onclick = () => refreshFeed(false);
    document.getElementById('viq-feed-auto').onchange = e => { settings.feedAutoOpen = e.target.checked; save(); };
  }

  function openFeed() {
    const feed = document.getElementById('viq-feed'); if (!feed) return;
    feed.classList.add('open');
    renderFeed();
    refreshFeed(false).then(markFeedSeen);
  }
  function closeFeed() {
    document.getElementById('viq-feed')?.classList.remove('open');
    markFeedSeen();
  }
  function markFeedSeen() {
    // remember what you've seen; badges in the open list stay until it's reopened
    const newest = feedVideos.reduce((m, v) => Math.max(m, v.lastAt), 0);
    if (newest > feedSeen) { feedSeen = newest; chrome.storage.local.set({ [FEED_SEEN_KEY]: feedSeen }); }
    updateFeedBadge();
  }

  async function refreshFeed(silent) {
    if (!cloudOn() || feedLoading) return;
    const open = document.getElementById('viq-feed')?.classList.contains('open');
    if (silent && !open && feedVideos.length && Date.now() - (refreshFeed.at || 0) < FEED_POLL_MS - 1000) return;
    feedLoading = true; refreshFeed.at = Date.now();
    if (!silent && open) renderFeed(true);
    try {
      feedVideos = groupFeed((await VIQ_CLOUD.getRecent(400)) || []);
      feedError = '';
    } catch (e) { feedError = e.message; }
    feedLoading = false;
    if (document.getElementById('viq-feed')?.classList.contains('open')) renderFeed();
    updateFeedBadge();
  }

  function groupFeed(rows) {
    const me = VIQ_CLOUD.getUser();
    const map = new Map();
    rows.forEach(r => {
      if (!/^[\w-]{6,20}$/.test(r.video_id || '')) return;
      let v = map.get(r.video_id);
      const at = Date.parse(r.updated_at) || 0;
      const anon = !!(r.style && r.style.anon);
      const who = anon ? { name: ANON_NAME, color: ANON_COLOR } : { name: r.profiles?.display_name || 'Someone', color: r.profiles?.color || '#a78bfa' };
      if (!v) {
        v = { id: r.video_id, title: '', count: 0, people: new Map(), lastAt: at, latest: { who, text: r.text },
              lastOther: 0 };
        map.set(r.video_id, v);
      }
      if (!v.title && r.video_title) v.title = cleanTitle(r.video_title);
      v.count++;
      const pk = anon ? 'anon' : r.user_id;
      if (!v.people.has(pk)) v.people.set(pk, who);
      if (!(me && r.user_id === me.id)) v.lastOther = Math.max(v.lastOther, at);
    });
    return [...map.values()].slice(0, 30);
  }

  function isNewVideo(v) { return v.lastOther > feedSeen; }

  function updateFeedBadge() {
    const b = document.getElementById('viq-feed-badge'); if (!b) return;
    const n = feedVideos.filter(isNewVideo).length;
    b.textContent = n > 9 ? '9+' : String(n);
    b.classList.toggle('hidden', !n);
  }

  function renderFeed(loading) {
    const list = document.getElementById('viq-feed-list'); if (!list) return;
    if (loading && !feedVideos.length) { list.innerHTML = '<div class="viq-feed-empty">Loading…</div>'; return; }
    if (feedError && !feedVideos.length) { list.innerHTML = '<div class="viq-feed-empty">⚠ ' + escH(feedError) + '</div>'; return; }
    if (!feedVideos.length) { list.innerHTML = '<div class="viq-feed-empty">No danmu yet. Open a video and write the first one!</div>'; return; }
    list.innerHTML = feedVideos.map(v => {
      const people = [...v.people.values()];
      const names  = people.slice(0, 3).map(p => '<span style="color:' + escH(p.color) + '">' + escH(p.name) + '</span>').join(', ') +
                     (people.length > 3 ? ' +' + (people.length - 3) : '');
      return (
        '<a class="viq-feed-item' + (v.id === videoId && getVideoId() ? ' current' : '') + '" href="/watch?v=' + v.id + '" data-id="' + v.id + '">' +
          '<span class="viq-feed-thumb"><img src="https://i.ytimg.com/vi/' + v.id + '/mqdefault.jpg" alt="" loading="lazy"/>' +
            (isNewVideo(v) ? '<span class="viq-feed-new">NEW</span>' : '') + '</span>' +
          '<span class="viq-feed-info">' +
            '<span class="viq-feed-vtitle">' + escH(v.title || 'YouTube video') + '</span>' +
            '<span class="viq-feed-meta">💬 ' + v.count + ' · ' + names + ' · ' + timeAgo(v.lastAt) + '</span>' +
            '<span class="viq-feed-last"><b style="color:' + escH(v.latest.who.color) + '">' + escH(v.latest.who.name) + ':</b> ' + escH(v.latest.text) + '</span>' +
          '</span>' +
        '</a>'
      );
    }).join('');
  }

  function timeAgo(ms) {
    const s = Math.max(0, (Date.now() - ms) / 1000);
    if (s < 60) return 'just now';
    if (s < 3600) return Math.floor(s / 60) + 'm ago';
    if (s < 86400) return Math.floor(s / 3600) + 'h ago';
    if (s < 86400 * 30) return Math.floor(s / 86400) + 'd ago';
    return new Date(ms).toLocaleDateString();
  }

  // "(3) Some title - YouTube" → "Some title"
  function cleanTitle(t) { return String(t || '').replace(/ - YouTube$/, '').replace(/^\(\d+\)\s*/, '').trim(); }
  function pageTitle()   { return cleanTitle(document.title); }

  // ── ACCOUNT ──────────────────────────────────────────────────────────────────
  // Signed-in account = your danmu name + color. Notes written under the old name
  // (e.g. before signing in) become yours and get uploaded.
  function adoptAccount(user) {
    const old = settings.username;
    if (old !== user.name) {
      for (const v in localNotes) localNotes[v].forEach(n => { if (n.user === old) { n.user = user.name; n.color = user.color; } });
      settings.username = user.name;
    }
    settings.color = user.color;
    save();
  }

  function onAccountChange(user) {
    if (user) {
      adoptAccount(user);
      const ni = document.getElementById('viq-username'); if (ni) ni.value = user.name;
      const ci = document.getElementById('viq-color');    if (ci) ci.value = user.color;
      pushAll().then(() => loadRemote(true));
    } else {
      loadRemote(true);
    }
    rebuildActive(); refreshSideList();
    updateAccountPill();
    if (!document.getElementById('viq-settings-panel')?.classList.contains('hidden')) buildAccountSection();
  }

  function updateAccountPill() {
    const pill = document.getElementById('viq-account-pill'); if (!pill) return;
    const u = VIQ_CLOUD.getUser();
    pill.innerHTML = u ? '<span class="viq-acc-dot"></span>' + escH(u.name) : '👤 Sign in';
    pill.title = u ? 'Signed in as ' + u.name + ' (' + u.email + ') — danmu are saved online' : 'Sign in to save your danmu online';
  }

  function openAccount() {
    if (settings.minimized) setMinimized(false);
    document.getElementById('viq-settings-panel').classList.remove('hidden');
    buildAuthorColorRows(); buildAccountSection();
    document.getElementById('viq-acc-email')?.focus();
  }

  function buildAccountSection() {
    const box = document.getElementById('viq-account-section'); if (!box) return;
    if (!cloudOn()) {
      box.innerHTML = '<div class="viq-acc-title">👤 Account</div>' +
        '<div class="viq-acc-msg">Online saving is not set up yet — see SETUP.md.</div>';
      return;
    }
    const u = VIQ_CLOUD.getUser();
    if (u) {
      box.innerHTML =
        '<div class="viq-acc-title">👤 Account</div>' +
        '<div class="viq-acc-msg ok">Signed in as <b style="color:' + escH(u.color) + '">' + escH(u.name) + '</b> · ' + escH(u.email) + '</div>' +
        '<div class="viq-acc-msg">Your danmu save online automatically. Change your name/color below and press Save.</div>' +
        '<div class="viq-acc-btns">' +
          '<button class="viq-recolor-btn" id="viq-acc-sync">⟳ Sync now</button>' +
          '<button class="viq-recolor-btn" id="viq-acc-out">Sign out</button>' +
        '</div>';
      document.getElementById('viq-acc-sync').onclick = () => pushAll().then(() => loadRemote());
      document.getElementById('viq-acc-out').onclick  = () => VIQ_CLOUD.signOut();
      return;
    }
    const defName = settings.username !== 'Me' ? settings.username : '';
    box.innerHTML = `
      <div class="viq-acc-title">👤 Account <span class="viq-acc-sub">— save your danmu online &amp; see everyone's</span></div>
      <div class="viq-acc-tabs">
        <button class="viq-acc-tab active" data-mode="in">Sign in</button>
        <button class="viq-acc-tab" data-mode="up">Create account</button>
      </div>
      <input id="viq-acc-name"  class="viq-input hidden" placeholder="Display name (everyone sees this)" maxlength="30" value="${escH(defName)}"/>
      <input id="viq-acc-email" class="viq-input" type="email" placeholder="Email" autocomplete="email"/>
      <input id="viq-acc-pass"  class="viq-input" type="password" placeholder="Password" autocomplete="current-password"/>
      <input id="viq-acc-code"  class="viq-input hidden" inputmode="numeric" autocomplete="one-time-code" placeholder="6-digit code from the email" maxlength="12"/>
      <div class="viq-acc-btns">
        <button class="viq-recolor-btn hidden" id="viq-acc-resend">Send a new code</button>
        <button class="viq-add-btn viq-acc-go" id="viq-acc-go">Sign in</button>
      </div>
      <div class="viq-acc-msg" id="viq-acc-msg"></div>`;
    let mode = 'in';
    const g = id => document.getElementById(id);
    // Account created but not confirmed yet → ask for the code from the email
    const showCodeStep = (email, note) => {
      mode = 'code';
      g('viq-acc-email').value = email;
      ['viq-acc-name','viq-acc-pass'].forEach(id => g(id).classList.add('hidden'));
      ['viq-acc-code','viq-acc-resend'].forEach(id => g(id).classList.remove('hidden'));
      g('viq-acc-go').textContent = 'Confirm';
      g('viq-acc-msg').className = 'viq-acc-msg ok';
      g('viq-acc-msg').textContent = note;
      g('viq-acc-code').focus();
    };
    box.querySelectorAll('.viq-acc-tab').forEach(t => t.onclick = () => {
      mode = t.dataset.mode;
      box.querySelectorAll('.viq-acc-tab').forEach(x => x.classList.toggle('active', x === t));
      ['viq-acc-code','viq-acc-resend'].forEach(id => g(id).classList.add('hidden'));
      g('viq-acc-pass').classList.remove('hidden');
      g('viq-acc-name').classList.toggle('hidden', mode !== 'up');
      g('viq-acc-pass').placeholder = mode === 'up' ? 'Password (at least 6 characters)' : 'Password';
      g('viq-acc-pass').autocomplete = mode === 'up' ? 'new-password' : 'current-password';
      g('viq-acc-go').textContent = mode === 'up' ? 'Create account' : 'Sign in';
      g('viq-acc-msg').textContent = ''; g('viq-acc-msg').className = 'viq-acc-msg';
    });
    g('viq-acc-resend').onclick = async () => {
      const msg = g('viq-acc-msg');
      try { await VIQ_CLOUD.resendCode(g('viq-acc-email').value); msg.className = 'viq-acc-msg ok'; msg.textContent = '✓ New code sent — check your email (also spam).'; }
      catch (e) { msg.className = 'viq-acc-msg err'; msg.textContent = '❌ ' + e.message; }
    };
    ['viq-acc-name','viq-acc-email','viq-acc-pass','viq-acc-code'].forEach(id =>
      g(id).onkeydown = e => { e.stopPropagation(); if (e.key === 'Enter' && !composing(e)) g('viq-acc-go').click(); });
    g('viq-acc-go').onclick = async () => {
      const msg = g('viq-acc-msg'), btn = g('viq-acc-go');
      const email = g('viq-acc-email').value.trim(), password = g('viq-acc-pass').value;
      msg.className = 'viq-acc-msg';
      if (mode === 'code') {
        btn.disabled = true; msg.textContent = 'Confirming…';
        try { await VIQ_CLOUD.verifyEmailCode({ email, code: g('viq-acc-code').value }); }
        catch (e) { msg.className = 'viq-acc-msg err'; msg.textContent = '❌ ' + e.message; }
        btn.disabled = false;
        return;
      }
      if (!email || !password) { msg.className = 'viq-acc-msg err'; msg.textContent = 'Enter your email and password'; return; }
      btn.disabled = true; msg.textContent = mode === 'up' ? 'Creating account…' : 'Signing in…';
      try {
        if (mode === 'up') {
          const r = await VIQ_CLOUD.signUp({ email, password, name: g('viq-acc-name').value, color: settings.color });
          if (!r.signedIn) showCodeStep(email, '✓ Account created! We emailed you a code — enter it here (check spam too).');
        } else {
          await VIQ_CLOUD.signIn({ email, password });
        }
      } catch (e) {
        if (/confirm your email/i.test(e.message)) {
          btn.disabled = false;
          showCodeStep(email, 'Your email isn\'t confirmed yet. Enter the code from the email, or press "Send a new code".');
          return;
        }
        msg.className = 'viq-acc-msg err'; msg.textContent = '❌ ' + e.message;
      }
      btn.disabled = false;
    };
  }

  // ── MERGE LOCAL + CLOUD ──────────────────────────────────────────────────────
  // allDanmu   = every note from everyone, sorted by adjusted time → used by sidebar
  // activeDanmu = only notes checked for VIDEO overlay → used by floating danmu
  function rebuildActive() {
    const mine = (localNotes[videoId] || []).slice();

    // Flatten cloud posts into note objects, applying per-user offset
    const cloudNotes = [];
    remoteAuthors().forEach(post => {
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
          _source:   post._source || 'cloud',
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
        videoEl = findActiveVideo();
        remoteList = []; visibleUsers = null; userOffsets = {};
        activeDanmu = [];
        editingId = null; pausedForNote = false; summaryMode = false;
        const onReady = () => {
          rebuildActive(); clearDanmuOverlay();
          refreshSideList(); buildUserSelector();
          updateShortsBadge();
          loadRemote();
        };
        if (videoEl) onReady();
        else {
          const w = setInterval(() => {
            videoEl = findActiveVideo();
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
    danmuContainer = document.createElement('div');
    danmuContainer.id = 'viq-danmu-overlay';
    (playerHost(videoEl) || document.body).appendChild(danmuContainer);
  }

  // ── WHICH VIDEO IS "THE" VIDEO? ──────────────────────────────────────────────
  // A YouTube page can hold several <video>s: the normal player (hidden while you
  // are on Shorts), hover previews, and one per short. Use the biggest one that is
  // actually on screen, preferring one that is playing.
  function findActiveVideo() {
    let best = null, bestScore = 0;
    document.querySelectorAll('video').forEach(v => {
      const r = v.getBoundingClientRect();
      const w = Math.min(r.right, innerWidth) - Math.max(r.left, 0);
      const h = Math.min(r.bottom, innerHeight) - Math.max(r.top, 0);
      if (w < 120 || h < 120) return;                       // hidden, off-screen or a tiny preview
      const score = w * h * (v.paused ? 1 : 4);
      if (score > bestScore) { best = v; bestScore = score; }
    });
    if (best) return best;
    // nothing visible yet (still loading) → the player that belongs to this kind of page
    return (isShorts ? document.querySelector('ytd-reel-video-renderer[is-active] video, #shorts-player video')
                     : document.querySelector('#movie_player video')) || null;
  }

  // The element that frames the video, so the danmu layer sits exactly on top of it
  function playerHost(v) {
    return v ? (v.closest('.html5-video-player') || v.closest('#player-container') || v.parentElement) : null;
  }

  // Follow the on-screen video (Shorts swipes, miniplayer, theater…) and keep the
  // danmu layer attached to its player
  function syncActiveVideo() {
    if (!getVideoId()) return;
    const v = findActiveVideo();
    if (!v) return;
    if (v !== videoEl) { videoEl = v; lastTime = -1; }
    const host = playerHost(v);
    if (danmuContainer && host && danmuContainer.parentElement !== host && !document.fullscreenElement) {
      danmuContainer.innerHTML = '';
      host.appendChild(danmuContainer);
    }
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
    const cloudOK = cloudOn();
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
          ${cloudOK ? '<button class="viq-publish-pill" id="viq-account-pill">👤 Sign in</button>' : ''}
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
          <div class="viq-account-section" id="viq-account-section"></div>
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
          <div class="viq-setting-row">
            <label><input type="checkbox" id="viq-toggle-names" ${settings.showNames!==false?'checked':''}/> Show names on danmu</label>
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
          <button id="viq-st-anon" class="viq-st-preview${st.anon ? ' anon' : ''}" title="Show my name on my danmu for everyone">${st.anon ? '🙈 Name hidden' : '👤 Name on'}</button>
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
        duration: parseInt(g('viq-st-dur').value, 10) || DEFAULT_STYLE.duration,
        anon:     !!(settings.danmuStyle && settings.danmuStyle.anon)
      };
      g('viq-st-dur').classList.toggle('hidden', mode !== 'top' && mode !== 'bottom');
      save();   // persisted — stays until the next change
      updateStyleSample();
    };
    ['viq-st-font','viq-st-size','viq-st-mode','viq-st-dur'].forEach(id => g(id).onchange = onChange);
    g('viq-st-color').oninput = onChange;
    g('viq-st-anon').onclick = () => {
      const anon = !(settings.danmuStyle && settings.danmuStyle.anon);
      settings.danmuStyle = Object.assign({}, curStyle(), { anon });
      save();
      g('viq-st-anon').textContent = anon ? '🙈 Name hidden' : '👤 Name on';
      g('viq-st-anon').classList.toggle('anon', anon);
      flashHint(anon ? '🙈 Your next danmu won\'t show your name to others' : '👤 Your next danmu will show your name');
    };
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
    document.getElementById('viq-mini-input').onkeydown = e => { if (e.key==='Enter' && !composing(e)) miniSend(); };
    document.getElementById('viq-mini-pause').onclick   = togglePause;
    document.getElementById('viq-mini-summary').onclick = openSummary;

    // settings
    document.getElementById('viq-settings-btn').onclick = () => {
      document.getElementById('viq-settings-panel').classList.toggle('hidden');
      buildAuthorColorRows();
      buildAccountSection();
    };
    document.getElementById('viq-save-settings').onclick = doSaveSettings;

    // note input
    const inp = document.getElementById('viq-quick-input');
    inp.onkeydown = e => {
      if (e.key === 'Enter' && !e.shiftKey && !composing(e)) { e.preventDefault(); quickAdd(); }
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

    // account
    const accPill = document.getElementById('viq-account-pill');
    if (accPill) { accPill.onclick = openAccount; updateAccountPill(); }

    setInterval(updateHint, 500);
    document.querySelectorAll('.viq-filter').forEach(btn => {
      btn.onclick = () => {
        document.querySelectorAll('.viq-filter').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        refreshSideList(btn.dataset.filter);
      };
    });
  }

  // ── USER SELECTOR ─────────────────────────────────────────────────────────────
  // Shows each cloud author as a row with: toggle, color, name, offset slider
  function buildUserSelector() {
    const el = document.getElementById('viq-user-selector'); if (!el) return;
    const authors = remoteAuthors();
    if (!authors.length) {
      el.classList.add('hidden');
      return;
    }
    el.classList.remove('hidden');

    el.innerHTML =
      '<div class="viq-us-title">👥 Others\' notes loaded — check to show on video, drag to adjust timing</div>' +
      authors.map(post => {
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
        const allNames = authors.map(p => p.author_name);
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
      panelHiddenByUser = v;
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
    saveVideoTitle(pageTitle());
    rebuildActive();
    if (settings.showOnVideo && !isSummary) launchFloat(note);
    refreshSideList();
    markChanged(note);
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
    note.text = text; rebuildActive(); markChanged(note);
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
    const gone = localNotes[videoId].find(n => n.id === id);
    localNotes[videoId] = localNotes[videoId].filter(n => n.id !== id);
    if (gone && gone._synced) {          // it exists online → delete it there too
      (pendingDeletes[videoId] = pendingDeletes[videoId] || []).push(id);
      chrome.storage.local.set({ [DEL_KEY]: pendingDeletes });
      scheduleSync();
    }
    save(); rebuildActive(); refreshSideList();
  }

  // ── EXPORT ───────────────────────────────────────────────────────────────────
  function exportMyNotes() {
    const notes = (localNotes[videoId]||[]).filter(n => n.user === settings.username);
    if (!notes.length) { flashHint('No notes of yours to export'); return; }
    const title   = document.title.replace(' - YouTube','').trim();
    const payload = {
      _meta: { author: settings.username, color: settings.color, exportedAt: new Date().toISOString(), videoTitle: title, videoId },
      [videoId]: notes.map(stripSync)
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
        localNotes[v].push(Object.assign(stripSync(e),{
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
    remoteAuthors().forEach(p=>{if(p.author_name!==settings.username) others[p.author_name]=others[p.author_name]||p.color||'#8892aa';});
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
        remoteAuthors().forEach(p=>{if(p.author_name===user){ p.color=col; p._recolored=true; }});
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
    // no name if the viewer turned names off (⚙) or the writer hid theirs on this danmu
    const hideName = (opts && opts.noName) || settings.showNames === false || !!st.anon;
    el.textContent = (hideName ? '' : '[' + (entry.user||entry.username) + '] ') + entry.text;
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
    if (mode === 'top' || mode === 'bottom') {
      // narrow players (Shorts): shrink a fixed danmu so the whole text fits
      const room = danmuContainer.clientWidth * 0.9;
      if (room > 0 && el.scrollWidth > room) el.style.fontSize = Math.max(11, Math.floor(px * room / el.scrollWidth)) + 'px';
    }
    setTimeout(() => el.remove(), lifeMs + 200);
  }
  function clearDanmuOverlay() { if (danmuContainer) danmuContainer.innerHTML = ''; }

  // ── TIME LOOP ─────────────────────────────────────────────────────────────────
  let syncTimer2 = null;
  function startLoop() {
    cancelAnimationFrame(animFrame);
    clearInterval(syncTimer2);
    syncTimer2 = setInterval(syncActiveVideo, 500);
    (function tick() {
      if (!videoEl || !videoEl.isConnected) videoEl = findActiveVideo();
      if (videoEl) {
        const t = Math.floor(videoEl.currentTime);
        if (t !== lastTime) { lastTime=t; checkTime(t); highlightList(t); }
      }
      animFrame = requestAnimationFrame(tick);
    })();
  }

  function checkTime(t) {
    if (!settings.showOnVideo || !getVideoId()) return;   // e.g. hover previews on the home page
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
    const cloudBadge= d._cloud ? '<span class="viq-cloud-badge" title="Saved online">☁</span>' : '';
    const mentionsMe = !isOwn && new RegExp('@' + escRe(settings.username) + '\\b', 'i').test(d.text||'');
    const eyeBadge  = (!onVideo && !isOwn) ? '<span class="viq-hidden-badge" title="Not shown on video">👁</span>' : '';
    const cls = [isOwn?'own':'other', isSummary?'summary-note':'', isEditing?'editing':'', !onVideo&&!isOwn?'note-dimmed':'', mentionsMe?'mentions-me':''].filter(Boolean).join(' ');
    return (
      '<div class="viq-list-item '+cls+'" data-time="'+d.time+'" data-id="'+d.id+'">' +
        '<div class="viq-item-main">' +
          '<span class="viq-item-time" data-time="'+d.time+'">'+(isSummary?'📋':d.ts)+'</span>' +
          '<span class="viq-item-user" style="color:'+escH(d.color)+'">'+escH(user)+'</span>' +
          (isOwn && d.style && d.style.anon ? '<span class="viq-hidden-badge" title="Your name is hidden on this danmu">🙈</span>' : '') +
          (isSummary?'<span class="viq-summary-tag">Summary</span>':'') +
          offBadge+cloudBadge+eyeBadge+
          '<span class="viq-item-text '+(isOwn?'editable':'')+'" data-id="'+d.id+'">'+escH(d.text)+'</span>' +
        '</div>' +
        '<div class="viq-item-actions">'+(isOwn
          ? '<button class="viq-del" data-id="'+d.id+'">✕</button>'
          : user === ANON_NAME ? ''
          : '<button class="viq-reply" data-user="'+escH(user)+'" data-time="'+d.time+'" title="Reply to '+escH(user)+'">↩</button>')+'</div>' +
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
    list.querySelectorAll('.viq-reply').forEach(btn=>{ btn.onclick=e=>{e.stopPropagation();replyTo(btn.dataset.user, parseInt(btn.dataset.time)||0);}; });
    list.querySelectorAll('.viq-del').forEach(btn=>{
      btn.onclick=e=>{e.stopPropagation();if(editingId===parseInt(btn.dataset.id)) cancelEdit();deleteNote(parseInt(btn.dataset.id));};
    });
  }

  // Reply: jump to the note's moment and start a "@name " danmu there
  function replyTo(user, time) {
    if (videoEl) { videoEl.currentTime = time; videoEl.pause(); pausedForNote = true; }
    if (settings.minimized) setMinimized(false);
    const inp = document.getElementById('viq-quick-input'); if (!inp) return;
    if (editingId !== null) cancelEdit();
    inp.value = '@' + user + ' ';
    inp.focus(); inp.setSelectionRange(inp.value.length, inp.value.length);
    updateHint();
  }

  // ── SETTINGS ─────────────────────────────────────────────────────────────────
  async function doSaveSettings() {
    const newName  = document.getElementById('viq-username').value.trim() || settings.username;
    const newColor = document.getElementById('viq-color').value;
    if (signedIn() && (newName !== settings.username || newColor !== settings.color)) {
      try { await VIQ_CLOUD.updateProfile({ name: newName, color: newColor }); }   // others see the change too
      catch (e) {
        document.getElementById('viq-username').value = settings.username;
        flashHint('❌ ' + e.message); return;
      }
    }
    if (newName !== settings.username)   // keep your existing notes yours under the new name
      for (const v in localNotes) localNotes[v].forEach(n => { if (n.user === settings.username) n.user = newName; });
    settings.username    = newName;
    settings.color       = newColor;
    settings.showOwn     = document.getElementById('viq-toggle-own').checked;
    settings.showOnVideo = document.getElementById('viq-toggle-video').checked;
    settings.showNames   = document.getElementById('viq-toggle-names').checked;
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
  // Drop local sync bookkeeping (_synced, _dirty…) from notes that leave or enter via JSON files
  function stripSync(n) {
    const o = {};
    for (const k in n) if (!['_synced','_syncedAt','_dirty','_rev'].includes(k)) o[k] = n[k];
    return o;
  }
  // True while an input method (Chinese/Japanese/Korean…) is still composing: the Enter
  // that picks the characters must not send the danmu (macOS sends it as a real keydown)
  function composing(e) { return e.isComposing || e.keyCode === 229; }
  function escRe(s) { return String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }
  function clamp(v,lo,hi) { return Math.max(lo,Math.min(v,hi)); }

  console.info('[VideoIQ] Danmu v' + chrome.runtime.getManifest().version + ' loaded on ' + location.pathname +
               (cloudOn() ? ' (online saving on)' : ' (online saving not configured)'));
  boot();
})();
