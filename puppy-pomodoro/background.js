// Puppy Pomodoro — background timer.
// All timing is stored as timestamps so the clock stays right even when
// Safari suspends this worker; alarms only wake us up to refresh the badge
// and to end the break.

const api = globalThis.browser ?? globalThis.chrome;
const KEY = 'pp';
const MIN = 60000;

// Sites you may use while focusing. "youtube.com/@handle" allows that
// channel's pages and its videos.
const DEFAULT_FOCUS_SITES = [
  'mit.edu',
  'youtube.com/@mit',
  'youtube.com/@mitocw',
  'chatgpt.com', 'chat.openai.com', 'auth.openai.com',
  'claude.ai',
  'gemini.google.com', 'accounts.google.com',
  'books.google.com', 'openlibrary.org', 'archive.org', 'gutenberg.org',
  'libbyapp.com', 'overdrive.com', 'learning.oreilly.com'
];

const TREATS = ['🦴', '🍖', '🧀', '🥕', '🍪', '🍗', '🥩'];

const DEFAULTS = {
  phase: 'idle',        // idle | focus | break | overtime
  paused: false,
  endsAt: null,         // focus goal / end of break (not paused)
  remaining: null,      // ms to endsAt while paused (negative past the goal)
  overtimeFrom: null,   // when the break ran out and the puppy went to the door
  targetMs: 0,          // length of this focus goal or break
  carryMs: 0,           // late-from-break time added to this focus goal
  sessions: 0,          // finished focus sessions
  treats: [],           // [{ t, at, bonus }]
  lastReward: null,     // { at, items } — shown as a toast
  settings: {
    focusMin: 25,
    breakMin: 5,
    bonusEveryMin: 5,
    sound: true,
    focusSites: DEFAULT_FOCUS_SITES
  }
};

async function load() {
  const saved = (await api.storage.local.get(KEY))[KEY] || {};
  const s = {
    ...DEFAULTS,
    ...saved,
    settings: { ...DEFAULTS.settings, ...(saved.settings || {}) }
  };
  delete s.garden;
  delete s.settings.sites;
  return s;
}

async function save(s) {
  await api.storage.local.set({ [KEY]: s });
  await schedule(s);
  await updateBadge(s);
}

// Run state changes one at a time so messages and alarms can't race.
let queue = Promise.resolve();
function serial(fn) {
  const next = queue.then(fn);
  queue = next.catch(() => {});
  return next;
}

// ---------- timing ----------

// ms until the focus goal / break end; negative once past it.
function leftMs(s, now) {
  if (s.paused) return s.remaining;
  return s.endsAt ? s.endsAt - now : 0;
}

// Treats earned so far in this focus session.
function earned(s, now) {
  if (s.phase !== 'focus') return 0;
  const extra = -leftMs(s, now);
  if (extra < 0) return 0;
  return 1 + Math.floor(extra / (s.settings.bonusEveryMin * MIN));
}

function advance(s, now) {
  if (s.phase === 'break' && !s.paused && s.endsAt && now >= s.endsAt) {
    s.phase = 'overtime';
    s.overtimeFrom = s.endsAt;
    s.endsAt = null;
  }
}

function startFocus(s, now, carryMs) {
  Object.assign(s, {
    phase: 'focus', paused: false, remaining: null, overtimeFrom: null,
    carryMs, targetMs: s.settings.focusMin * MIN + carryMs
  });
  s.endsAt = now + s.targetMs;
}

function startBreak(s, now) {
  Object.assign(s, {
    phase: 'break', paused: false, remaining: null, carryMs: 0,
    targetMs: s.settings.breakMin * MIN
  });
  s.endsAt = now + s.targetMs;
}

function toIdle(s) {
  Object.assign(s, {
    phase: 'idle', paused: false, endsAt: null, remaining: null,
    overtimeFrom: null, targetMs: 0, carryMs: 0
  });
}

// Give the puppy its treats for this focus session.
function reward(s, now) {
  const n = earned(s, now);
  if (!n) return false;
  const items = Array.from({ length: n }, (_, i) => ({
    t: TREATS[Math.floor(Math.random() * TREATS.length)], at: now + i, bonus: i > 0
  }));
  s.treats = [...s.treats, ...items];
  s.lastReward = { at: now, items: items.map(x => x.t) };
  s.sessions += 1;
  return true;
}

// ---------- which sites are for focus ----------

function parseEntry(e) {
  const clean = String(e).trim().toLowerCase().replace(/^https?:\/\//, '').replace(/^www\./, '');
  const i = clean.indexOf('/');
  const host = i < 0 ? clean : clean.slice(0, i);
  const path = i < 0 ? '' : clean.slice(i).replace(/\/+$/, '');
  return host ? { host, path } : null;
}

const hostMatches = (host, e) => host === e || host.endsWith('.' + e);

// 'focus' | 'distraction' | 'pending' (YouTube video, channel not known yet) | 'ignore'
function classify(url, channel, sites) {
  let u;
  try { u = new URL(url); } catch { return 'ignore'; }
  if (!/^https?:$/.test(u.protocol)) return 'ignore';
  const host = u.hostname.toLowerCase().replace(/^www\./, '');
  const path = u.pathname.toLowerCase();
  const entries = sites.map(parseEntry).filter(Boolean);

  for (const e of entries) {
    if (!hostMatches(host, e.host)) continue;
    if (!e.path || path === e.path || path.startsWith(e.path + '/')) return 'focus';
  }

  const isYouTube = hostMatches(host, 'youtube.com') || host === 'youtu.be';
  const isVideo = host === 'youtu.be' || path === '/watch' || path.startsWith('/shorts/') || path.startsWith('/live/');
  if (isYouTube && isVideo) {
    const channels = entries
      .filter(e => hostMatches('youtube.com', e.host) && e.path.startsWith('/@'))
      .map(e => e.path.slice(1).split('/')[0]);
    if (!channels.length) return 'distraction';
    if (channel == null) return 'pending';
    return channels.includes(String(channel).toLowerCase()) ? 'focus' : 'distraction';
  }
  return 'distraction';
}

const appUrl = (q = '') => api.runtime.getURL('app.html' + q);

// Close every non-focus tab. YouTube videos are checked by their page.
async function closeDistractions(sites) {
  const tabs = await api.tabs.query({});
  const byWindow = new Map();
  for (const t of tabs) {
    if (!byWindow.has(t.windowId)) byWindow.set(t.windowId, []);
    byWindow.get(t.windowId).push(t);
  }
  for (const list of byWindow.values()) {
    const kinds = list.map(t => (t.url ? classify(t.url, null, sites) : 'ignore'));
    list.forEach((t, i) => {
      if (kinds[i] === 'pending') api.tabs.sendMessage(t.id, { cmd: 'recheck' }).catch(() => {});
    });
    const bad = list.filter((_, i) => kinds[i] === 'distraction');
    if (!bad.length) continue;
    // Don't close a whole window: keep one tab and send it to the puppy.
    if (bad.length === list.length) {
      const keep = bad.shift();
      await api.tabs.update(keep.id, { url: appUrl('?tab=1') }).catch(() => {});
    }
    if (bad.length) await api.tabs.remove(bad.map(t => t.id)).catch(() => {});
  }
}

// A tab is showing `url`. Before the focus goal, distractions are sent back
// to the puppy; after the goal, opening one starts the break.
async function visit(s, now, tabId, url, channel) {
  if (s.phase !== 'focus' || s.paused) return false;
  if (classify(url, channel, s.settings.focusSites) !== 'distraction') return false;
  if (leftMs(s, now) > 0) {
    let host = '';
    try { host = new URL(url).hostname.replace(/^www\./, ''); } catch {}
    api.tabs.update(tabId, { url: appUrl('?tab=1&blocked=' + encodeURIComponent(host)) }).catch(() => {});
    return false;
  }
  reward(s, now);
  startBreak(s, now);
  return true;
}

api.tabs.onUpdated.addListener((tabId, change) => {
  if (!change.url) return;
  serial(async () => {
    const s = await load();
    const now = Date.now();
    advance(s, now);
    if (await visit(s, now, tabId, change.url, null)) await save(s);
  });
});

// ---------- alarms and the toolbar badge ----------

async function schedule(s) {
  await api.alarms.clear('phase');
  await api.alarms.clear('tick');
  if (s.endsAt && !s.paused) api.alarms.create('phase', { when: s.endsAt });
  if (s.phase !== 'idle') api.alarms.create('tick', { periodInMinutes: 0.5 });
}

async function updateBadge(s) {
  const now = Date.now();
  const left = leftMs(s, now);
  let text = '';
  let color = '#3a8d5c';
  if (s.phase === 'focus') {
    text = left > 0 ? Math.ceil(left / MIN) + 'm' : '+' + Math.max(1, Math.ceil(-left / MIN)) + 'm';
    color = left > 0 ? '#3a8d5c' : '#c58a00';
  } else if (s.phase === 'break') {
    text = Math.max(1, Math.ceil(left / MIN)) + 'm';
    color = '#3b7dd8';
  } else if (s.phase === 'overtime') {
    text = '-' + Math.max(1, Math.ceil((now - s.overtimeFrom) / MIN)) + 'm';
    color = '#d9433b';
  }
  if (s.paused) {
    text = '||';
    color = '#8a8a8a';
  }
  await api.action.setBadgeText({ text }).catch(() => {});
  if (api.action.setBadgeBackgroundColor) {
    await api.action.setBadgeBackgroundColor({ color }).catch(() => {});
  }
  const label = s.phase === 'idle' ? 'Puppy Pomodoro' : `Puppy Pomodoro · ${text}`;
  await api.action.setTitle?.({ title: label }).catch(() => {});
}

async function sync() {
  const s = await load();
  const before = s.phase;
  advance(s, Date.now());
  if (s.phase !== before) await save(s);
  else await updateBadge(s);
  return s;
}

api.alarms.onAlarm.addListener(() => serial(sync));
api.runtime.onStartup?.addListener(() => serial(sync));
api.runtime.onInstalled.addListener(() => serial(sync));

// ---------- commands from the pages ----------

function cleanSettings(cur, inc) {
  const num = (v, lo, hi, d) => {
    const n = Number(v);
    return Number.isFinite(n) ? Math.min(hi, Math.max(lo, Math.round(n))) : d;
  };
  const out = { ...cur, ...inc };
  out.focusMin = num(out.focusMin, 1, 180, cur.focusMin);
  out.breakMin = num(out.breakMin, 1, 60, cur.breakMin);
  out.bonusEveryMin = num(out.bonusEveryMin, 1, 60, cur.bonusEveryMin);
  if (!Array.isArray(out.focusSites)) out.focusSites = cur.focusSites;
  out.focusSites = [...new Set(out.focusSites
    .map(parseEntry).filter(Boolean).map(e => e.host + e.path))];
  return out;
}

async function command(msg, sender) {
  const s = await load();
  const now = Date.now();
  advance(s, now);

  switch (msg.cmd) {
    case 'start':
      if (msg.settings) s.settings = cleanSettings(s.settings, msg.settings);
      startFocus(s, now, 0);
      await closeDistractions(s.settings.focusSites);
      break;
    case 'pause':
      if ((s.phase === 'focus' || s.phase === 'break') && !s.paused) {
        s.remaining = s.endsAt - now;
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
      reward(s, now);
      toIdle(s);
      break;
    case 'takeBreak':
      if (reward(s, now)) startBreak(s, now);
      break;
    case 'release': // let the puppy out and go back to focus
      if (s.phase === 'break' || s.phase === 'overtime') {
        const late = s.phase === 'overtime' ? Math.max(0, now - s.overtimeFrom) : 0;
        startFocus(s, now, late);
        await closeDistractions(s.settings.focusSites);
      }
      break;
    case 'visit':
      if (sender?.tab?.id == null || !(await visit(s, now, sender.tab.id, msg.url, msg.channel))) {
        return s;
      }
      break;
    case 'settings':
      s.settings = cleanSettings(s.settings, msg.settings || {});
      break;
    case 'clearTreats':
      s.treats = [];
      break;
    case 'sync':
      break;
  }

  await save(s);
  return s;
}

api.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  serial(() => command(msg, sender)).then(sendResponse, err => sendResponse({ error: String(err) }));
  return true;
});
