// Puppy Pomodoro — runs on web pages.
// 1. Tells the background which page (and which YouTube channel) is open.
// 2. When the break is over, keeps a small puppy window on top of the page.
// 3. Shows short toasts: focus goal reached, treats earned.

(() => {
  if (window.top !== window || window.__puppyPomodoro) return;
  window.__puppyPomodoro = true;

  const api = globalThis.browser ?? globalThis.chrome;
  const KEY = 'pp';
  let state = null;

  const send = msg => {
    try {
      return api.runtime.sendMessage(msg).catch(() => {});
    } catch {
      return Promise.resolve(); // extension was reloaded
    }
  };

  // ---------- report the page ----------

  let lastUrl = null;
  let urlSince = 0;
  let lastReport = '';

  function isYouTubeVideo() {
    const h = location.hostname;
    const p = location.pathname;
    return /(^|\.)youtube\.com$/.test(h) && (p === '/watch' || p.startsWith('/shorts/') || p.startsWith('/live/'));
  }

  // '@handle', null while the page is still loading, '?' if it can't tell.
  function youTubeChannel(now) {
    if (location.pathname.startsWith('/shorts/')) return '?';
    const v = new URLSearchParams(location.search).get('v');
    const flexy = document.querySelector('ytd-watch-flexy');
    const ready = flexy && (!v || flexy.getAttribute('video-id') === v) && now - urlSince > 1500;
    if (ready) {
      const a = document.querySelector('ytd-watch-metadata ytd-channel-name a, #owner ytd-channel-name a, ytd-video-owner-renderer a[href]');
      const href = a?.getAttribute('href') || '';
      const m = href.match(/\/(@[^/?#]+)/);
      if (m) return decodeURIComponent(m[1]).toLowerCase();
      if (href) return '?';
    }
    return now - urlSince > 8000 ? '?' : null;
  }

  function report(force) {
    const now = Date.now();
    if (location.href !== lastUrl) {
      lastUrl = location.href;
      urlSince = now;
    }
    const channel = isYouTubeVideo() ? youTubeChannel(now) : undefined;
    const key = location.href + '|' + channel;
    if (!force && key === lastReport) return;
    lastReport = key;
    send({ cmd: 'visit', url: location.href, channel: channel ?? null });
  }

  api.runtime.onMessage.addListener(msg => {
    if (msg && msg.cmd === 'recheck') {
      lastReport = '';
      report(true);
    }
  });

  // ---------- small window + toasts (in a shadow root so pages can't restyle it) ----------

  const host = document.createElement('puppy-pomodoro');
  host.style.cssText = 'all: initial; position: fixed; inset: 0; pointer-events: none; z-index: 2147483647;';
  const root = host.attachShadow({ mode: 'open' });
  root.innerHTML = `
    <style>
      :host { all: initial; }
      * { box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
      .card { position: fixed; right: 16px; bottom: 16px; width: 250px; pointer-events: auto;
        background: #fffaf2; color: #2d2620; border: 2px solid #d9433b; border-radius: 16px;
        box-shadow: 0 10px 30px rgba(0,0,0,.28); padding: 10px 12px 12px; display: none; text-align: center; }
      .card.left { right: auto; left: 16px; }
      .card.on { display: block; animation: pop .35s ease-out; }
      .head { display: flex; justify-content: space-between; align-items: center; font-size: 12px;
        font-weight: 700; color: #d9433b; text-transform: uppercase; letter-spacing: .05em; }
      .move { all: unset; cursor: pointer; color: #8a7f74; font-size: 14px; padding: 0 2px; }
      .time { font-size: 34px; font-weight: 800; color: #d9433b; font-variant-numeric: tabular-nums;
        line-height: 1.1; animation: pulse 1s ease-in-out infinite; }
      .msg { font-size: 12px; color: #6b6158; margin: 2px 0 8px; }
      svg { width: 100%; height: auto; display: block; border-radius: 10px; }
      button.go { all: unset; cursor: pointer; display: block; width: 100%; margin-top: 8px; background: #d9433b;
        color: #fff; font-weight: 700; font-size: 14px; padding: 9px 0; border-radius: 10px; }
      button.go:hover { filter: brightness(.95); }
      .toast { position: fixed; left: 50%; top: 16px; transform: translateX(-50%); pointer-events: auto;
        background: #2d2620; color: #fff; padding: 10px 16px; border-radius: 12px; font-size: 14px;
        box-shadow: 0 8px 24px rgba(0,0,0,.3); max-width: 90vw; display: none; }
      .toast.on { display: block; animation: drop .35s ease-out; }
      .fur { fill: #e0a96d; } .dark, .leg { fill: #c98a4f; } .light { fill: #f7dfbd; }
      .ear { fill: #8a5a2b; } .ink { fill: #2b1d14; }
      .collar { stroke: #d9433b; stroke-width: 3.5; fill: none; stroke-linecap: round; }
      .tail { stroke: #c98a4f; stroke-width: 6; fill: none; stroke-linecap: round;
        transform-origin: 16px 36px; animation: wag .18s ease-in-out infinite alternate; }
      .pup { transform: translate(64px, 44px) rotate(-24deg); transform-origin: 31px 59px; transform-box: view-box; }
      .paw { transform-origin: 68px 40px; transform-box: view-box; animation: scratch .28s ease-in-out infinite alternate; }
      .scr { stroke: #f3d2a8; stroke-width: 1.6; stroke-linecap: round; fill: none; }
      @keyframes wag { from { transform: rotate(-12deg); } to { transform: rotate(14deg); } }
      @keyframes scratch { from { transform: rotate(-115deg); } to { transform: rotate(-70deg); } }
      @keyframes pulse { 50% { opacity: .55; } }
      @keyframes pop { from { transform: scale(.6); opacity: 0; } }
      @keyframes drop { from { transform: translate(-50%, -20px); opacity: 0; } }
    </style>
    <div class="card" part="card">
      <div class="head"><span>🐾 Break is over</span><button class="move" title="Move to the other side">⇆</button></div>
      <svg viewBox="0 0 230 110" aria-hidden="true">
        <rect width="230" height="92" fill="#f6e7cf"/>
        <rect y="92" width="230" height="18" fill="#c99a6b"/>
        <rect x="160" y="14" width="54" height="78" fill="#8f6a47"/>
        <rect x="165" y="19" width="44" height="73" fill="#b77d4c"/>
        <circle cx="202" cy="58" r="3" fill="#e8c45a"/>
        <path class="scr" d="M168 66 l5 13 M172 64 l5 14 M176 66 l4 12"/>
        <g class="pup">
          <path class="tail" d="M16 36 Q2 26 8 10"/>
          <ellipse class="dark" cx="27" cy="49" rx="13" ry="11"/>
          <ellipse class="leg" cx="31" cy="59" rx="10" ry="3.2"/>
          <ellipse class="fur" cx="42" cy="40" rx="29" ry="17"/>
          <ellipse class="light" cx="48" cy="47" rx="17" ry="8"/>
          <rect class="fur" x="57" y="40" width="10" height="20" rx="5"/>
          <circle class="fur" cx="78" cy="22" r="17"/>
          <ellipse class="light" cx="94" cy="29" rx="10" ry="7"/>
          <ellipse class="ink" cx="102.5" cy="25.5" rx="3.4" ry="2.7"/>
          <circle class="ink" cx="85" cy="17" r="2.4"/>
          <ellipse class="ear" cx="70" cy="22" rx="6.5" ry="13" transform="rotate(14 70 22)"/>
          <path class="collar" d="M66 34 q10 7 20 2"/>
          <g class="paw"><rect class="fur" x="63" y="36" width="10" height="23" rx="5"/></g>
        </g>
      </svg>
      <div class="time">−00:00</div>
      <div class="msg">Puppy is scratching the door! This time gets added to your next focus.</div>
      <button class="go">🐾 End the fun — let puppy out</button>
    </div>
    <div class="toast"></div>`;

  const card = root.querySelector('.card');
  const timeEl = root.querySelector('.time');
  const toastEl = root.querySelector('.toast');

  root.querySelector('.go').addEventListener('click', () => send({ cmd: 'release' }));
  root.querySelector('.move').addEventListener('click', () => card.classList.toggle('left'));

  function mount() {
    if (!host.isConnected && document.documentElement) document.documentElement.appendChild(host);
  }

  let toastTimer = null;
  function toast(text) {
    mount();
    toastEl.textContent = text;
    toastEl.classList.add('on');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove('on'), 7000);
  }
  toastEl.addEventListener('click', () => toastEl.classList.remove('on'));

  function fmt(ms) {
    const t = Math.floor(Math.abs(ms) / 1000);
    const h = Math.floor(t / 3600);
    const m = Math.floor((t % 3600) / 60);
    const s = String(t % 60).padStart(2, '0');
    return h ? `${h}:${String(m).padStart(2, '0')}:${s}` : `${String(m).padStart(2, '0')}:${s}`;
  }

  let wasBeforeGoal = null;

  function render() {
    if (!state) return;
    const now = Date.now();
    const s = state;

    const over = s.phase === 'overtime';
    if (over) {
      mount();
      timeEl.textContent = '−' + fmt(now - s.overtimeFrom);
      if (!card.classList.contains('on')) card.classList.add('on');
      if (document.fullscreenElement) document.exitFullscreen?.().catch(() => {});
    } else {
      card.classList.remove('on');
    }

    // Focus goal reached while this page is in front.
    if (s.phase === 'focus' && !s.paused && s.endsAt) {
      const before = s.endsAt - now > 0;
      if (wasBeforeGoal && !before && document.visibilityState === 'visible') {
        toast('🎉 Focus goal reached! Puppy earned a treat 🦴 Keep going for bonus treats, or open another site to start your break.');
      }
      wasBeforeGoal = before;
    } else {
      wasBeforeGoal = null;
    }
  }

  function setState(s) {
    const prev = state;
    state = s;
    const r = s.lastReward;
    if (r && r.at !== prev?.lastReward?.at && Date.now() - r.at < 5000 &&
        s.phase === 'break' && document.visibilityState === 'visible') {
      toast(`☕ Break time! Puppy got ${r.items.join('')} — enjoy your ${s.settings.breakMin} min break.`);
    }
    render();
  }

  api.storage.local.get(KEY).then(o => o[KEY] && setState(o[KEY]));
  api.storage.onChanged.addListener((changes, area) => {
    if (area === 'local' && changes[KEY]?.newValue) setState(changes[KEY].newValue);
  });

  report(true);
  setInterval(() => {
    report(false);
    render();
  }, 1000);
})();
