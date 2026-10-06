// Puppy Pomodoro — runs on web pages.
// 1. Tells the background which page (and which YouTube channel) is open.
// 2. When the break is over, keeps a small window with Pork on top of the page.
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
      .top { display: flex; justify-content: space-between; align-items: center; font-size: 12px;
        font-weight: 700; color: #d9433b; text-transform: uppercase; letter-spacing: .05em; }
      .move { all: unset; cursor: pointer; color: #8a7f74; font-size: 14px; padding: 0 2px; }
      .time { font-size: 34px; font-weight: 800; color: #d9433b; font-variant-numeric: tabular-nums;
        line-height: 1.1; animation: pulse 1s ease-in-out infinite; }
      .msg { font-size: 12px; color: #6b6158; margin: 2px 0 8px; }
      svg { width: 100%; height: auto; display: block; border-radius: 10px; }
      button.go { all: unset; cursor: pointer; display: block; width: 100%; margin-top: 8px; background: #d9433b;
        color: #fff; font-weight: 700; font-size: 14px; padding: 9px 0; border-radius: 10px; }
      button.go:hover { filter: brightness(.95); }
      .mini { position: fixed; right: 12px; bottom: 12px; pointer-events: auto; display: none;
        align-items: center; gap: 5px; height: 28px; padding: 0 9px 0 3px; border-radius: 14px;
        background: rgba(255, 250, 242, .94); color: #2d2620; border: 1px solid #e3d6c3;
        box-shadow: 0 2px 8px rgba(0,0,0,.18); font-size: 13px; font-weight: 700; cursor: pointer;
        font-variant-numeric: tabular-nums; user-select: none; transition: opacity .2s; line-height: 1; }
      .mini.on { display: flex; }
      .mini.left { right: auto; left: 12px; }
      .mini:hover { opacity: .2; }
      .mini svg { width: 22px; height: 22px; flex: none; }
      .mini .t.goal { color: #c58a00; }
      .mini .t.brk { color: #3b7dd8; }
      .mini .tr { font-weight: 600; font-size: 12px; color: #8a7f74; }
      .toast { position: fixed; left: 50%; top: 16px; transform: translateX(-50%); pointer-events: auto;
        background: #2d2620; color: #fff; padding: 10px 16px; border-radius: 12px; font-size: 14px;
        box-shadow: 0 8px 24px rgba(0,0,0,.3); max-width: 90vw; display: none; }
      .toast.on { display: block; animation: drop .35s ease-out; }
      ${PORK_CSS}
      .pos { transform-box: view-box; transform: translate(108px, 46px) scale(.8); }
      [data-pose="pace"] .pos { animation: pk-pace 3.2s ease-in-out infinite; }
      [data-pose="pace"] .smudge { opacity: 0; }
      @keyframes pk-pace { 0%, 100% { transform: translate(14px, 44px) scale(.8); } 50% { transform: translate(84px, 44px) scale(.8); } }
      @keyframes pulse { 50% { opacity: .55; } }
      @keyframes pop { from { transform: scale(.6); opacity: 0; } }
      @keyframes drop { from { transform: translate(-50%, -20px); opacity: 0; } }
    </style>
    <div class="card" part="card">
      <div class="top"><span>🐾 Break is over</span><button class="move" title="Move to the other side">⇆</button></div>
      <svg viewBox="0 0 230 110" aria-hidden="true">
        <rect width="230" height="92" fill="#f6e7cf"/>
        <rect y="92" width="230" height="18" fill="#c99a6b"/>
        <rect x="158" y="12" width="58" height="80" fill="#fbfbf9" stroke="#cfcac2"/>
        <rect x="164" y="18" width="46" height="66" fill="#bfe3ff" opacity=".6"/>
        <path d="M187 18 v66 M164 40 h46 M164 62 h46" stroke="#fbfbf9" stroke-width="3"/>
        <rect x="205" y="50" width="2.5" height="11" rx="1.2" fill="#9ea3ab"/>
        <g class="smudge" fill="#8a7f74" opacity=".35">
          <ellipse cx="170" cy="70" rx="2.6" ry="2"/><ellipse cx="176" cy="66" rx="2.6" ry="2"/><ellipse cx="172" cy="61" rx="2.2" ry="1.8"/>
        </g>
        <g class="pos">${PORK_SVG}</g>
      </svg>
      <div class="time">−00:00</div>
      <div class="msg"></div>
      <button class="go">🐾 End the fun — let Pork out</button>
    </div>
    <div class="mini" title="Puppy Pomodoro (click to move to the other side)">
      <svg viewBox="0 0 128 128" aria-hidden="true">
        <circle cx="64" cy="64" r="62" fill="#22396b"/>
        <ellipse cx="28" cy="70" rx="15" ry="30" fill="#9c9c98" transform="rotate(14 28 70)"/>
        <ellipse cx="100" cy="70" rx="15" ry="30" fill="#9c9c98" transform="rotate(-14 100 70)"/>
        <circle cx="64" cy="64" r="36" fill="#fbfbf8"/>
        <circle cx="50" cy="60" r="6" fill="#3a2418"/><circle cx="78" cy="60" r="6" fill="#3a2418"/>
        <ellipse cx="64" cy="78" rx="9" ry="7" fill="#1d1d1d"/>
      </svg>
      <span class="t"></span><span class="tr"></span>
    </div>
    <div class="toast"></div>`;

  const card = root.querySelector('.card');
  const timeEl = root.querySelector('.time');
  const msgEl = root.querySelector('.msg');
  const PACE_MS = 2 * 60000; // after the break: pace this long, then scratch
  const toastEl = root.querySelector('.toast');
  const mini = root.querySelector('.mini');
  const miniTime = mini.querySelector('.t');
  const miniTreat = mini.querySelector('.tr');
  mini.addEventListener('click', () => mini.classList.toggle('left'));

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

  function render() {
    if (!state) return;
    const now = Date.now();
    const s = state;

    const over = s.phase === 'overtime';
    if (over) {
      mount();
      const late = now - s.overtimeFrom;
      timeEl.textContent = '−' + fmt(late);
      const pose = late < PACE_MS ? 'pace' : 'door';
      if (card.dataset.pose !== pose) {
        card.dataset.pose = pose;
        msgEl.textContent = pose === 'pace'
          ? 'Pork is pacing, he wants to go out! This time gets added to your next focus.'
          : 'Pork is scratching the door! This time gets added to your next focus.';
      }
      if (!card.classList.contains('on')) card.classList.add('on');
      if (document.fullscreenElement) document.exitFullscreen?.().catch(() => {});
    } else {
      card.classList.remove('on');
    }

    // Small Pork clock in the corner while focusing or on a break.
    const showMini = s.settings.miniClock !== false && !over &&
      (s.phase === 'focus' || s.phase === 'break') && !document.fullscreenElement;
    mini.classList.toggle('on', showMini);
    if (showMini) {
      mount();
      const left = s.paused ? s.remaining : s.endsAt - now;
      const pause = s.paused ? '⏸ ' : '';
      miniTime.className = 't';
      if (s.phase === 'break') {
        miniTime.classList.add('brk');
        miniTime.textContent = pause + '☕ ' + fmt(Math.max(0, left));
        miniTreat.textContent = '';
      } else if (left > 0) {
        miniTime.textContent = pause + fmt(left);
        miniTreat.textContent = s.nextTreat || '🦴';
      } else {
        miniTime.classList.add('goal');
        miniTime.textContent = pause + '+' + fmt(-left);
        const every = s.settings.bonusEveryMin * 60000;
        const next = left + (s.paid || 0) * every;
        miniTreat.textContent = `${s.nextTreat || '🦴'} ${fmt(Math.max(0, next))}`;
      }
    }
  }

  function setState(s) {
    const prev = state;
    state = s;
    const now = Date.now();
    const visible = document.visibilityState === 'visible';
    const r = s.lastReward;
    const newTreat = r && r.at !== prev?.lastReward?.at && now - r.at < 5000;
    const breakStart = s.phase === 'break' && s.endsAt ? s.endsAt - s.targetMs : null;
    const newBreak = breakStart && now - breakStart < 5000 && prev?.phase !== 'break';
    if (visible && newBreak) {
      toast(`☕ Break time!${newTreat ? ` Pork got ${r.items.join('')}.` : ''} Enjoy your ${s.settings.breakMin} min break, Pork is waiting by the door.`);
    } else if (visible && newTreat && s.phase === 'focus') {
      toast(r.bonus
        ? `🎁 Bonus treat! Pork got ${r.items.join('')} for your extra focus.`
        : `🎉 Focus goal reached! Pork got ${r.items.join('')} Keep going for bonus treats!`);
    }
    const a = s.lastAuto;
    if (a && a.at !== prev?.lastAuto?.at && Date.now() - a.at < 5000 && document.visibilityState === 'visible') {
      toast(a.how === 'resume'
        ? '🐶 Pork resumed your focus by itself. Back to work!'
        : `🐶 Pork started your focus by itself (${s.settings.focusMin} min). Only focus sites until the goal!`);
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
