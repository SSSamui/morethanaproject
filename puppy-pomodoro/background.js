// Puppy Pomodoro — background timer.
// All timing is stored as timestamps so the clock stays right even when
// Safari suspends this worker; alarms only wake us up at phase changes.

const api = globalThis.browser ?? globalThis.chrome;
const KEY = 'pp';
const MIN = 60000;

const DEFAULT_SITES = [
  'youtube.com', 'tiktok.com', 'instagram.com', 'facebook.com', 'x.com',
  'twitter.com', 'reddit.com', 'netflix.com', 'twitch.tv', 'bilibili.com',
  'poki.com', 'crazygames.com', 'miniclip.com', 'roblox.com'
];

const DEFAULTS = {
  phase: 'idle',        // idle | focus | break | overtime
  paused: false,
  endsAt: null,         // when the current focus/break ends (not paused)
  remaining: null,      // ms left while paused
  overtimeFrom: null,   // when the break ran out and the puppy went to the door
  sessionMs: 0,         // length of the current focus/break
  extraMs: 0,           // overtime added on to this focus session
  sessions: 0,          // finished focus sessions
  garden: [],           // [{ plant, at, overtimeMs }]
  lastRelease: null,    // { at, plant, overtimeMs } for the door animation
  settings: {
    focusMin: 25,
    breakMin: 5,
    autoBreak: true,
    blockDuringFocus: true,
    openTab: true,
    sound: true,
    sites: DEFAULT_SITES
  }
};

async function load() {
  const saved = (await api.storage.local.get(KEY))[KEY] || {};
  return {
    ...DEFAULTS,
    ...saved,
    settings: { ...DEFAULTS.settings, ...(saved.settings || {}) }
  };
}

async function save(s) {
  await api.storage.local.set({ [KEY]: s });
  await schedule(s);
  await updateBadge(s);
}

// Run state changes one at a time so a message and an alarm can't race.
let queue = Promise.resolve();
function serial(fn) {
  const next = queue.then(fn);
  queue = next.catch(() => {});
  return next;
}

// ---------- phase changes ----------

function advance(s, now) {
  const events = [];
  if (s.paused || !s.endsAt) return events;
  if (s.phase === 'focus' && now >= s.endsAt) {
    s.sessions += 1;
    if (s.settings.autoBreak) startBreak(s, now);
    else toIdle(s);
    events.push('focusDone');
  }
  if (s.phase === 'break' && now >= s.endsAt) {
    s.phase = 'overtime';
    s.overtimeFrom = s.endsAt;
    s.endsAt = null;
    events.push('breakDone');
  }
  return events;
}

function startFocus(s, now, extraMs) {
  s.phase = 'focus';
  s.paused = false;
  s.remaining = null;
  s.overtimeFrom = null;
  s.extraMs = extraMs;
  s.sessionMs = s.settings.focusMin * MIN + extraMs;
  s.endsAt = now + s.sessionMs;
}

function startBreak(s, now) {
  s.phase = 'break';
  s.paused = false;
  s.remaining = null;
  s.extraMs = 0;
  s.sessionMs = s.settings.breakMin * MIN;
  s.endsAt = now + s.sessionMs;
}

function toIdle(s) {
  Object.assign(s, {
    phase: 'idle', paused: false, endsAt: null, remaining: null,
    overtimeFrom: null, sessionMs: 0, extraMs: 0
  });
}

function pickPlant(overtimeMs) {
  const m = overtimeMs / MIN;
  const pool = m <= 1 ? ['🌳', '🌲', '🌸', '🌻', '🌷', '🌺', '🌴', '🌹']
    : m <= 5 ? ['🌼', '🪴', '🌿', '🍀']
    : ['🌱'];
  return pool[Math.floor(Math.random() * pool.length)];
}

// Let the puppy out: plant something, then go back to work with the
// overtime added to the focus session.
function release(s, now) {
  const overtimeMs = s.phase === 'overtime' ? Math.max(0, now - s.overtimeFrom) : 0;
  const plant = pickPlant(overtimeMs);
  s.garden = [...s.garden, { plant, at: now, overtimeMs }];
  s.lastRelease = { at: now, plant, overtimeMs };
  startFocus(s, now, overtimeMs);
}

// ---------- distractions ----------

function hostOf(url) {
  try {
    const u = new URL(url);
    return /^https?:$/.test(u.protocol) ? u.hostname.replace(/^www\./, '') : null;
  } catch {
    return null;
  }
}

function isDistraction(url, sites) {
  const host = hostOf(url);
  return !!host && sites.some(d => host === d || host.endsWith('.' + d));
}

const appUrl = (q = '') => api.runtime.getURL('app.html' + q);

async function closeDistractions(sites) {
  const tabs = await api.tabs.query({});
  const byWindow = new Map();
  for (const t of tabs) {
    if (!byWindow.has(t.windowId)) byWindow.set(t.windowId, []);
    byWindow.get(t.windowId).push(t);
  }
  for (const list of byWindow.values()) {
    const bad = list.filter(t => t.url && isDistraction(t.url, sites));
    if (!bad.length) continue;
    // Don't close a whole window: keep one tab and send it to the puppy.
    if (bad.length === list.length) {
      const keep = bad.shift();
      await api.tabs.update(keep.id, { url: appUrl('?tab=1') }).catch(() => {});
    }
    if (bad.length) await api.tabs.remove(bad.map(t => t.id)).catch(() => {});
  }
}

// Keep distractions away while focusing.
api.tabs.onUpdated.addListener(async (tabId, change) => {
  if (!change.url) return;
  const s = await load();
  if (s.phase !== 'focus' || !s.settings.blockDuringFocus) return;
  if (isDistraction(change.url, s.settings.sites)) {
    const host = hostOf(change.url);
    api.tabs.update(tabId, { url: appUrl('?tab=1&blocked=' + encodeURIComponent(host)) }).catch(() => {});
  }
});

// ---------- puppy tab, alarms, badge ----------

async function showPuppy() {
  const base = appUrl();
  const tabs = await api.tabs.query({});
  const open = tabs.find(t => t.url && t.url.startsWith(base));
  if (open) {
    await api.tabs.update(open.id, { active: true }).catch(() => {});
    if (api.windows) await api.windows.update(open.windowId, { focused: true }).catch(() => {});
  } else {
    await api.tabs.create({ url: appUrl('?tab=1') }).catch(() => {});
  }
}

async function schedule(s) {
  await api.alarms.clear('phase');
  await api.alarms.clear('tick');
  if (s.endsAt && !s.paused) api.alarms.create('phase', { when: s.endsAt });
  if (s.phase !== 'idle') api.alarms.create('tick', { periodInMinutes: 0.5 });
}

async function updateBadge(s) {
  const now = Date.now();
  let text = '';
  let color = '#3a8d5c';
  if (s.paused) {
    text = '||';
    color = '#8a8a8a';
  } else if (s.phase === 'focus' || s.phase === 'break') {
    text = String(Math.max(1, Math.ceil((s.endsAt - now) / MIN)));
    color = s.phase === 'focus' ? '#3a8d5c' : '#3b7dd8';
  } else if (s.phase === 'overtime') {
    text = '-' + Math.floor((now - s.overtimeFrom) / MIN);
    color = '#d9433b';
  }
  await api.action.setBadgeText({ text }).catch(() => {});
  if (api.action.setBadgeBackgroundColor) {
    await api.action.setBadgeBackgroundColor({ color }).catch(() => {});
  }
}

async function react(s, events) {
  if (!events.length) return;
  if (events.includes('breakDone') || events.includes('focusDone')) {
    if (s.settings.openTab) await showPuppy();
  }
}

async function sync() {
  const s = await load();
  const events = advance(s, Date.now());
  if (events.length) await save(s);
  else await updateBadge(s);
  await react(s, events);
  return s;
}

api.alarms.onAlarm.addListener(() => serial(sync));
api.runtime.onStartup?.addListener(() => serial(sync));
api.runtime.onInstalled.addListener(() => serial(sync));

// ---------- commands from the page ----------

function cleanSettings(cur, inc) {
  const num = (v, lo, hi, d) => {
    const n = Number(v);
    return Number.isFinite(n) ? Math.min(hi, Math.max(lo, Math.round(n))) : d;
  };
  const out = { ...cur, ...inc };
  out.focusMin = num(out.focusMin, 1, 180, cur.focusMin);
  out.breakMin = num(out.breakMin, 1, 60, cur.breakMin);
  if (!Array.isArray(out.sites)) out.sites = cur.sites;
  out.sites = [...new Set(out.sites
    .map(x => String(x).trim().toLowerCase()
      .replace(/^https?:\/\//, '').replace(/^www\./, '').replace(/\/.*$/, ''))
    .filter(Boolean))];
  return out;
}

async function command(msg) {
  const s = await load();
  const now = Date.now();
  const events = advance(s, now);

  switch (msg.cmd) {
    case 'start':
      if (msg.settings) s.settings = cleanSettings(s.settings, msg.settings);
      startFocus(s, now, 0);
      await closeDistractions(s.settings.sites);
      break;
    case 'pause':
      if ((s.phase === 'focus' || s.phase === 'break') && !s.paused) {
        s.remaining = Math.max(0, s.endsAt - now);
        s.endsAt = null;
        s.paused = true;
      }
      break;
    case 'resume':
      if (s.paused) {
        s.endsAt = now + s.remaining;
        s.remaining = null;
        s.paused = false;
      }
      break;
    case 'stop':
      toIdle(s);
      break;
    case 'takeBreak':
      if (s.phase === 'focus') {
        s.sessions += 1;
        startBreak(s, now);
      }
      break;
    case 'release':
      if (s.phase === 'break' || s.phase === 'overtime') {
        release(s, now);
        await closeDistractions(s.settings.sites);
      }
      break;
    case 'settings':
      s.settings = cleanSettings(s.settings, msg.settings || {});
      break;
    case 'clearGarden':
      s.garden = [];
      break;
    case 'sync':
      break;
  }

  await save(s);
  if (msg.cmd === 'sync') await react(s, events);
  return s;
}

api.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  serial(() => command(msg)).then(sendResponse, err => sendResponse({ error: String(err) }));
  return true;
});
