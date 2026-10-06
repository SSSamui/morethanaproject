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

// Added in 2.3.0: Outlook and Word on the web, and Kindle.
const ADDED_SITES_2 = [
  'outlook.office.com', 'outlook.office365.com', 'outlook.live.com', 'outlook.com',
  'office.com', 'microsoft365.com', 'cloud.microsoft', 'officeapps.live.com',
  'onedrive.live.com', 'sharepoint.com', 'login.microsoftonline.com', 'login.live.com',
  'read.amazon.com', 'amazon.com/ap'
];
// Added in 2.3.2: the danmu site (YouTube videos with danmu, played inside the page).
const ADDED_SITES_3 = ['sssamui.github.io/morethanaproject/danmu'];

// Added in 2.4.1: Google (search and all google.com services) and Notion.
const ADDED_SITES_4 = [
  'google.com', 'mail.google.com', 'drive.google.com', 'docs.google.com',
  'calendar.google.com', 'tasks.google.com',
  'notion.so', 'notion.com', 'notion.site'
];

// Sites added in each update, so saved lists get them too.
const ADDED_SITES = { 2: ADDED_SITES_2, 3: ADDED_SITES_3, 4: ADDED_SITES_4 };
DEFAULT_FOCUS_SITES.push(...ADDED_SITES_2, ...ADDED_SITES_3, ...ADDED_SITES_4);
const SITES_REV = 4;

const TREATS = ['🦴', '🍖', '🧀', '🥕', '🍪', '🍗', '🥩'];

const DEFAULTS = {
  phase: 'idle',        // idle | focus | break | overtime
  paused: false,
  endsAt: null,         // focus goal / end of break (not paused)
  remaining: null,      // ms to endsAt while paused (negative past the goal)
  overtimeFrom: null,   // when the break ran out and the puppy went to the door
  targetMs: 0,          // length of this focus goal or break
  carryMs: 0,           // late-from-break time added to this focus goal
  sessions: 0,          // focus sessions that reached the goal
  paid: 0,              // treats already given in this focus session
  nextTreat: null,      // the treat Pork gets next (shown next to the time)
  treats: [],           // [{ t, at, bonus }]
  lastReward: null,     // { at, items, bonus } — shown as a toast
  stoppedAt: null,      // when the clock was stopped (idle)
  pausedAt: null,       // when the clock was paused
  lastAuto: null,       // { at, how: 'start' | 'resume', why } — shown as a toast
  nightShut: null,      // which night (start time + hours) already closed the non-focus tabs
  settings: {
    focusMin: 25,
    breakMin: 5,
    bonusEveryMin: 5,
    sound: true,
    autoStartOnOpen: true,   // start when Safari opens or the Mac wakes up
    autoRestartMin: 30,      // start again after paused/stopped this long (0 = never)
    nightLock: true,         // night mode: only focus sites between these times
    nightStart: '00:00',
    nightEnd: '06:00',
    keepTab: true,           // keep Pork's page open as a (pinned) tab
    miniClock: true,         // small Pork clock in the corner of web pages
    focusSites: DEFAULT_FOCUS_SITES,
    sitesRev: SITES_REV      // which default sites the saved list already has
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
  // Give an older saved list the sites added since.
  const rev = saved.settings ? saved.settings.sitesRev || 1 : SITES_REV;
  if (rev < SITES_REV) {
    const added = Object.keys(ADDED_SITES).filter(r => r > rev).flatMap(r => ADDED_SITES[r]);
    s.settings.focusSites = [...new Set([...s.settings.focusSites, ...added])];
    s.settings.sitesRev = SITES_REV;
    s.dirty = true;
  }
  if (!s.nextTreat) s.nextTreat = pickTreat();
  return s;
}

async function save(s) {
  delete s.dirty;
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

// ---------- night mode ----------

const toMinutes = hhmm => {
  const [h, m] = String(hhmm).split(':').map(Number);
  return (h || 0) * 60 + (m || 0);
};

// Is `now` inside the night-mode hours? (They can wrap past midnight, e.g. 22:00–06:00.)
function isNight(s, now) {
  const st = s.settings;
  if (!st.nightLock) return false;
  const d = new Date(now);
  const m = d.getHours() * 60 + d.getMinutes();
  const a = toMinutes(st.nightStart);
  const b = toMinutes(st.nightEnd);
  if (a === b) return true;
  return a < b ? m >= a && m < b : m >= a || m < b;
}

// Names the current night: the date it began plus its hours, e.g. "2026-10-06 00:00-06:00".
function nightKey(s, now) {
  const d = new Date(now);
  const m = d.getHours() * 60 + d.getMinutes();
  if (m < toMinutes(s.settings.nightStart)) d.setDate(d.getDate() - 1);
  const day = `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
  return `${day} ${s.settings.nightStart}-${s.settings.nightEnd}`;
}

// When a paused or stopped clock starts again by itself (null = never).
function autoAt(s) {
  const n = s.settings.autoRestartMin;
  if (!n) return null;
  if (s.phase === 'idle' && s.stoppedAt) return s.stoppedAt + n * MIN;
  if (s.paused && s.pausedAt) return s.pausedAt + n * MIN;
  return null;
}

function pause(s, now) {
  if ((s.phase === 'focus' || s.phase === 'break') && !s.paused) {
    s.remaining = s.endsAt - now;
    s.endsAt = null;
    s.paused = true;
    s.pausedAt = now;
  }
}

function resume(s, now) {
  if (s.paused) {
    s.endsAt = now + s.remaining;
    s.remaining = null;
    s.paused = false;
    s.pausedAt = null;
  }
}

// Start focus (if stopped) or resume (if paused) without a click.
// A shorter focus or longer break only counts for one session: the next
// session goes back to at least 25 min of focus and at most 5 min of break.
const MIN_FOCUS = 25;
const MAX_BREAK = 5;
function backToNormal(s) {
  s.settings.focusMin = Math.max(MIN_FOCUS, s.settings.focusMin);
  s.settings.breakMin = Math.min(MAX_BREAK, s.settings.breakMin);
}

async function autoStart(s, now, why) {
  if (s.phase === 'idle') {
    backToNormal(s);
    startFocus(s, now, 0);
    s.lastAuto = { at: now, how: 'start', why };
    await closeDistractions(s.settings.focusSites);
    return true;
  }
  if (s.paused) {
    resume(s, now);
    s.lastAuto = { at: now, how: 'resume', why };
    return true;
  }
  return false;
}

// Move the clock along: end the break, or restart after a long pause/stop.
// Returns true if anything changed.
async function tick(s, now) {
  const before = s.phase + s.paused + s.paid;
  advance(s, now);
  if (s.phase === 'focus' && !s.paused) payTreats(s, now);
  // Night mode just began (or Safari opened during it): close non-focus tabs once per night.
  let nightNow = false;
  if (isNight(s, now)) {
    const key = nightKey(s, now);
    if (s.nightShut !== key) {
      s.nightShut = key;
      nightNow = true;
      await closeDistractions(s.settings.focusSites);
    }
  }
  if (s.phase === 'idle' && !s.stoppedAt) s.stoppedAt = now;
  const at = autoAt(s);
  if (at && now >= at) await autoStart(s, now, 'timer');
  return s.phase + s.paused + s.paid !== before || s.stoppedAt === now || nightNow;
}

function startFocus(s, now, carryMs) {
  Object.assign(s, {
    phase: 'focus', paused: false, remaining: null, overtimeFrom: null,
    stoppedAt: null, pausedAt: null, paid: 0,
    carryMs, targetMs: s.settings.focusMin * MIN + carryMs
  });
  s.endsAt = now + s.targetMs;
}

function startBreak(s, now) {
  Object.assign(s, {
    phase: 'break', paused: false, remaining: null, carryMs: 0, pausedAt: null,
    targetMs: s.settings.breakMin * MIN
  });
  s.endsAt = now + s.targetMs;
}

function toIdle(s, now) {
  Object.assign(s, {
    phase: 'idle', paused: false, endsAt: null, remaining: null,
    overtimeFrom: null, targetMs: 0, carryMs: 0, stoppedAt: now, pausedAt: null
  });
}

const pickTreat = () => TREATS[Math.floor(Math.random() * TREATS.length)];

// When Pork gets his next treat in this focus session (goal, then every bonus).
function nextTreatAt(s) {
  if (s.phase !== 'focus' || s.paused || !s.endsAt) return null;
  return s.endsAt + (s.paid || 0) * s.settings.bonusEveryMin * MIN;
}

// Give Pork every treat he has earned so far in this focus session.
function payTreats(s, now) {
  const n = earned(s, now);
  const items = [];
  while ((s.paid || 0) < n) {
    items.push({ t: s.nextTreat || pickTreat(), at: now + items.length, bonus: (s.paid || 0) > 0 });
    if (!s.paid) s.sessions += 1;
    s.paid = (s.paid || 0) + 1;
    s.nextTreat = pickTreat();
  }
  if (!items.length) return;
  s.treats = [...s.treats, ...items];
  s.lastReward = { at: now, items: items.map(x => x.t), bonus: items[0].bonus };
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
  if (classify(url, channel, s.settings.focusSites) !== 'distraction') return false;
  let host = '';
  try { host = new URL(url).hostname.replace(/^www\./, ''); } catch {}
  const block = extra => api.tabs.update(tabId, {
    url: appUrl('?tab=1&blocked=' + encodeURIComponent(host) + extra)
  }).catch(() => {});
  // Night mode: only focus sites, whatever the clock is doing.
  if (isNight(s, now)) {
    block('&night=1');
    return false;
  }
  if (s.phase !== 'focus' || s.paused) return false;
  if (leftMs(s, now) > 0) {
    block('');
    return false;
  }
  payTreats(s, now);
  startBreak(s, now);
  return true;
}

api.tabs.onUpdated.addListener((tabId, change) => {
  if (!change.url) return;
  serial(async () => {
    const s = await load();
    const now = Date.now();
    const changed = await tick(s, now);
    if ((await visit(s, now, tabId, change.url, null)) || changed) await save(s);
  });
});

// ---------- alarms and the toolbar badge ----------

async function schedule(s) {
  await api.alarms.clear('phase');
  await api.alarms.clear('tick');
  await api.alarms.clear('auto');
  await api.alarms.clear('treat');
  if (s.endsAt && !s.paused) api.alarms.create('phase', { when: s.endsAt });
  const treatAt = nextTreatAt(s);
  if (treatAt && treatAt > s.endsAt) api.alarms.create('treat', { when: treatAt });
  if (s.phase !== 'idle') api.alarms.create('tick', { periodInMinutes: 0.5 });
  const at = autoAt(s);
  if (at) api.alarms.create('auto', { when: Math.max(at, Date.now() + 1000) });
  // Heartbeat: a long gap between beats means the Mac was asleep.
  if (!(await api.alarms.get('beat'))) api.alarms.create('beat', { periodInMinutes: 1 });
}

// Badge time: minutes, or whole hours from 1 hour on (the badge has room for ~4 characters).
const short = mins => (mins < 60 ? mins + 'm' : Math.floor(mins / 60) + 'h');

async function updateBadge(s) {
  const now = Date.now();
  const left = leftMs(s, now);
  let text = '';
  let color = '#3a8d5c';
  if (s.phase === 'focus') {
    text = left > 0 ? short(Math.ceil(left / MIN)) : '+' + short(Math.max(1, Math.ceil(-left / MIN)));
    color = left > 0 ? '#3a8d5c' : '#c58a00';
  } else if (s.phase === 'break') {
    text = Math.max(1, Math.ceil(left / MIN)) + 'm';
    color = '#3b7dd8';
  } else if (s.phase === 'overtime') {
    text = '-' + short(Math.max(1, Math.ceil((now - s.overtimeFrom) / MIN)));
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

async function sync(why) {
  const s = await load();
  const now = Date.now();
  let changed = await tick(s, now);
  if (why && s.settings.autoStartOnOpen) changed = (await autoStart(s, now, why)) || changed;
  if (changed || s.dirty) await save(s);
  else await updateBadge(s);
  if (!(await api.alarms.get('beat'))) api.alarms.create('beat', { periodInMinutes: 1 });
  await ensurePorkTab(s);
  return s;
}

const SLEEP_GAP = 5 * MIN;

async function heartbeat() {
  const now = Date.now();
  const last = (await api.storage.local.get('ppBeat')).ppBeat || now;
  await api.storage.local.set({ ppBeat: now });
  return sync(now - last > SLEEP_GAP ? 'wake' : null);
}

api.alarms.onAlarm.addListener(a => serial(() => (a.name === 'beat' ? heartbeat() : sync())));
// Safari opened.
api.runtime.onStartup?.addListener(() => serial(async () => {
  await api.storage.local.set({ ppBeat: Date.now() });
  return sync('open');
}));
api.runtime.onInstalled.addListener(details => serial(async () => {
  const s = await sync();
  // Just installed: show Pork's page (it explains the Safari permissions).
  if (details?.reason === 'install') await ensurePorkTab(s, true);
}));

// ---------- Pork's tab, always open ----------

let porkTabMadeAt = 0;

// Make sure one tab shows Pork's page (pinned, first in the window).
async function ensurePorkTab(s, show = false) {
  if (!s.settings.keepTab && !show) return;
  const tabs = await api.tabs.query({}).catch(() => []);
  if (!tabs.length) return; // no Safari window open
  const base = appUrl();
  const mine = tabs.find(t => (t.url || t.pendingUrl || '').startsWith(base));
  if (mine) {
    if (show) await api.tabs.update(mine.id, { active: true }).catch(() => {});
    return;
  }
  if (Date.now() - porkTabMadeAt < 5000) return; // one is still loading
  porkTabMadeAt = Date.now();
  const win = await api.windows?.getLastFocused?.().catch(() => null);
  const opts = { url: appUrl('?tab=1'), active: show, index: 0 };
  if (win && win.id != null) opts.windowId = win.id;
  try {
    await api.tabs.create({ ...opts, pinned: true });
  } catch {
    await api.tabs.create(opts).catch(() => {});
  }
}

// Pork's tab was closed: open it again (unless the whole window is closing).
api.tabs.onRemoved.addListener((tabId, info) => {
  if (info && info.isWindowClosing) return;
  serial(async () => ensurePorkTab(await load()));
});
// First Safari window opened again after all windows were closed.
api.windows?.onCreated?.addListener(() => serial(async () => {
  const wins = await api.windows.getAll().catch(() => []);
  return sync(wins.length <= 1 ? 'open' : null);
}));

// ---------- commands from the pages ----------

function cleanSettings(cur, inc) {
  const num = (v, lo, hi, d) => {
    const n = Number(v);
    return Number.isFinite(n) ? Math.min(hi, Math.max(lo, Math.round(n))) : d;
  };
  const out = { ...cur, ...inc };
  out.focusMin = num(out.focusMin, 1, 720, cur.focusMin);
  out.breakMin = num(out.breakMin, 1, 60, cur.breakMin);
  out.bonusEveryMin = num(out.bonusEveryMin, 1, 60, cur.bonusEveryMin);
  out.autoRestartMin = num(out.autoRestartMin, 0, 600, cur.autoRestartMin);
  out.autoStartOnOpen = !!out.autoStartOnOpen;
  out.nightLock = !!out.nightLock;
  out.keepTab = !!out.keepTab;
  out.miniClock = !!out.miniClock;
  const hhmm = (v, d) => (/^\d{1,2}:\d{2}$/.test(String(v)) ? String(v).padStart(5, '0') : d);
  out.nightStart = hhmm(out.nightStart, cur.nightStart);
  out.nightEnd = hhmm(out.nightEnd, cur.nightEnd);
  if (!Array.isArray(out.focusSites)) out.focusSites = cur.focusSites;
  out.focusSites = [...new Set(out.focusSites
    .map(parseEntry).filter(Boolean).map(e => e.host + e.path))];
  return out;
}

async function command(msg, sender) {
  const s = await load();
  const now = Date.now();
  const changed = await tick(s, now);

  switch (msg.cmd) {
    case 'start':
      if (msg.settings) s.settings = cleanSettings(s.settings, msg.settings);
      startFocus(s, now, 0);
      await closeDistractions(s.settings.focusSites);
      break;
    case 'pause':
      pause(s, now);
      break;
    case 'resume':
      resume(s, now);
      break;
    case 'stop':
      payTreats(s, now);
      toIdle(s, now);
      break;
    case 'takeBreak':
      if (earned(s, now)) {
        payTreats(s, now);
        startBreak(s, now);
      }
      break;
    case 'release': // let the puppy out and go back to focus
      if (s.phase === 'break' || s.phase === 'overtime') {
        const late = s.phase === 'overtime' ? Math.max(0, now - s.overtimeFrom) : 0;
        backToNormal(s);
        startFocus(s, now, late);
        await closeDistractions(s.settings.focusSites);
      }
      break;
    case 'visit':
      const visited = sender?.tab?.id != null && (await visit(s, now, sender.tab.id, msg.url, msg.channel));
      if (!visited && !changed) return s;
      break;
    case 'settings':
      s.settings = cleanSettings(s.settings, msg.settings || {});
      break;
    case 'clearTreats':
      s.treats = [];
      break;
    case 'sync':
      break;
    case 'floatPrompt': // for Pork's tab, nothing to change here
      return s;
  }

  await save(s);
  return s;
}

api.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  serial(() => command(msg, sender)).then(sendResponse, err => sendResponse({ error: String(err) }));
  return true;
});
