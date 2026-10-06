// Puppy Pomodoro — popup and tab page. The background worker owns the
// timer; this page draws it and sends commands.

const api = globalThis.browser ?? globalThis.chrome;
const KEY = 'pp';
const $ = id => document.getElementById(id);

const params = new URLSearchParams(location.search);
const isTab = params.has('tab');
if (isTab) document.body.classList.add('tab');
if (params.has('mini')) document.body.classList.add('mini');

const app = $('app');
const MIN = 60000;
const PACE_MS = 2 * MIN; // after the break: pace this long, then scratch

$('pupPos').innerHTML = PORK_SVG;
const porkStyle = document.createElement('style');
porkStyle.textContent = PORK_CSS;
document.head.appendChild(porkStyle);
let state = null;
let releasingUntil = 0;
let seenTreats = null;
let lastSync = 0;

if (params.get('blocked')) {
  $('blocked').hidden = false;
  $('blocked').textContent = `🐶 ${params.get('blocked')} isn't a focus site. Pork is napping, keep focusing!`;
}

function isNight(st, now) {
  if (!st.nightLock) return false;
  const d = new Date(now);
  const m = d.getHours() * 60 + d.getMinutes();
  const mins = t => t.split(':').map(Number).reduce((h, x) => h * 60 + x);
  const a = mins(st.nightStart);
  const b = mins(st.nightEnd);
  if (a === b) return true;
  return a < b ? m >= a && m < b : m >= a || m < b;
}

function send(cmd, extra = {}) {
  return api.runtime.sendMessage({ cmd, ...extra }).then(s => {
    if (s && !s.error) setState(s);
    return s;
  });
}

function fmt(ms) {
  const total = Math.floor(Math.abs(ms) / 1000);
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const mm = String(m).padStart(h ? 2 : 1, '0');
  const ss = String(s).padStart(2, '0');
  return h ? `${h}:${mm}:${ss}` : `${mm.padStart(2, '0')}:${ss}`;
}

function setState(s) {
  const prev = state;
  // Back to focus from the break: play the door animation.
  if (prev && (prev.phase === 'break' || prev.phase === 'overtime') && s.phase === 'focus') {
    releasingUntil = Math.max(releasingUntil, Date.now() + 3200);
  }
  state = s;
  if (!prev) fillSettings();
  // Focus/break minutes can change by themselves (back to 25/5): show the new values.
  for (const k of ['focusMin', 'breakMin']) {
    if (prev && document.activeElement !== $(k) && prev.settings[k] !== s.settings[k]) $(k).value = s.settings[k];
  }
  if (!prev && params.get('night')) {
    $('blocked').textContent = `🌙 Night mode: only focus sites can open now. ${params.get('blocked')} is blocked.`;
  }
  renderTreats();
  render();
}

function fillSettings() {
  const st = state.settings;
  $('focusMin').value = st.focusMin;
  $('breakMin').value = st.breakMin;
  $('bonusEveryMin').value = st.bonusEveryMin;
  $('autoStartOnOpen').checked = st.autoStartOnOpen;
  $('autoRestartMin').value = st.autoRestartMin;
  $('nightLock').checked = st.nightLock;
  $('nightStart').value = st.nightStart;
  $('nightEnd').value = st.nightEnd;
  $('keepTab').checked = st.keepTab;
  $('miniClock').checked = st.miniClock;
  $('sound').checked = st.sound;
  $('sites').value = st.focusSites.join('\n');
}

function readSettings() {
  return {
    focusMin: Number($('focusMin').value),
    breakMin: Number($('breakMin').value),
    bonusEveryMin: Number($('bonusEveryMin').value),
    autoStartOnOpen: $('autoStartOnOpen').checked,
    autoRestartMin: Number($('autoRestartMin').value),
    keepTab: $('keepTab').checked,
    miniClock: $('miniClock').checked,
    sound: $('sound').checked,
    focusSites: $('sites').value.split(/[\s,]+/)
  };
}

function render() {
  if (!state) return;
  const now = Date.now();
  const s = state;
  const left = s.paused ? s.remaining : s.endsAt ? s.endsAt - now : 0;
  const goal = s.phase === 'focus' && left <= 0;

  // Next treat: at the focus goal, then every bonus interval of extra focus.
  const every = s.settings.bonusEveryMin * MIN;
  const paid = s.paid || 0;
  const untilTreat = s.phase === 'focus' ? left + paid * every
    : s.phase === 'idle' ? Number($('focusMin').value || s.settings.focusMin) * MIN : null;

  // The worker may be asleep; nudge it if the break should have ended or a treat is due.
  const due = (s.phase === 'break' && left <= 0) || (s.phase === 'focus' && untilTreat <= 0);
  if (due && !s.paused && now - lastSync > 1000) {
    lastSync = now;
    send('sync');
  }

  app.dataset.phase = s.phase;
  if (s.paused) app.dataset.paused = '';
  else delete app.dataset.paused;
  if (goal) app.dataset.goal = '';
  else delete app.dataset.goal;

  let label, time, sub = '';
  switch (s.phase) {
    case 'focus': {
      const paused = s.paused ? ' · paused' : '';
      if (!goal) {
        label = 'Focus' + paused;
        time = fmt(left);
        sub = s.carryMs > 0
          ? `${fmt(s.settings.focusMin * MIN)} + ${fmt(s.carryMs)} from the long break`
          : 'Only focus sites until the goal 🐶';
      } else {
        const got = paid ? (s.treats || []).slice(-paid).map(t => t.t) : [];
        label = 'Extra focus' + paused;
        time = '+' + fmt(-left);
        sub = got.length ? `Pork got ${got.slice(-8).join('')}${got.length > 8 ? ' ×' + got.length : ''} this session 🐶` : '';
      }
      break;
    }
    case 'break':
      label = s.paused ? 'Break · paused' : 'Break';
      time = fmt(Math.max(0, left));
      sub = 'Pork is waiting by the door 🚪';
      break;
    case 'overtime':
      label = 'Break is over!';
      time = '−' + fmt(now - s.overtimeFrom);
      sub = now - s.overtimeFrom < PACE_MS
        ? 'Pork is pacing, he wants to go out! This time gets added to your next focus.'
        : 'Pork is scratching the door! This time gets added to your next focus.';
      break;
    default:
      label = 'Ready to focus';
      time = fmt(Number($('focusMin').value || s.settings.focusMin) * MIN);
      sub = s.sessions ? `${s.sessions} focus session${s.sessions > 1 ? 's' : ''} done` : '';
  }
  // When a paused or stopped clock starts again by itself.
  const n = s.settings.autoRestartMin;
  const autoAt = !n ? null
    : s.phase === 'idle' && s.stoppedAt ? s.stoppedAt + n * MIN
    : s.paused && s.pausedAt ? s.pausedAt + n * MIN : null;
  $('autoNote').textContent = autoAt
    ? `🐶 ${s.paused ? 'Resumes' : 'Focus starts'} by itself at ${new Date(autoAt).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })} (in ${fmt(Math.max(0, autoAt - now))})`
    : '';

  $('nightNote').textContent = isNight(s.settings, now)
    ? '🌙 Night mode: only focus sites'
    : '';

  $('treatChip').hidden = untilTreat == null;
  if (untilTreat != null) {
    $('chipTreat').textContent = s.nextTreat || '🦴';
    $('chipLabel').textContent = paid ? 'Pork will get a bonus treat after' : 'Pork will get a treat after';
    $('chipTime').textContent = fmt(Math.max(0, untilTreat));
  }

  $('label').textContent = label;
  $('time').textContent = time;
  $('sub').textContent = sub;

  let pose = 'sleep';
  if (now < releasingUntil) pose = 'out';
  else if (s.phase === 'break') pose = 'wait';
  else if (s.phase === 'overtime') pose = now - s.overtimeFrom < PACE_MS ? 'pace' : 'door';
  app.dataset.pose = pose;
  $('bubbleText').textContent = pose === 'pace' ? 'Can we go out? 🥺' : 'Woof! Let me out!';

  document.title = s.phase === 'idle' ? 'Puppy Pomodoro' : `${time} · ${label}`;
  scratchSound(pose === 'door' && s.settings.sound);
}

function renderTreats() {
  const list = state.treats || [];
  const box = $('treats');
  const known = seenTreats;
  box.textContent = '';
  if (!list.length) {
    const el = document.createElement('span');
    el.className = 'empty';
    el.textContent = `Focus ${state.settings.focusMin} min to give Pork a treat. Every ${state.settings.bonusEveryMin} min of extra focus = a bonus treat!`;
    box.appendChild(el);
  }
  for (const t of list) {
    const el = document.createElement('span');
    el.textContent = t.t;
    el.title = new Date(t.at).toLocaleString() + (t.bonus ? ' · bonus for extra focus' : ' · focus goal');
    if (known !== null && !known.has(t.at)) el.className = 'new';
    box.appendChild(el);
  }
  seenTreats = new Set(list.map(t => t.at));
  $('treatCount').textContent = list.length ? `${list.length} treat${list.length > 1 ? 's' : ''}` : 'no treats yet';
  box.scrollTop = box.scrollHeight;
}

// ---------- scratching sound (soft noise bursts) ----------

let audio = null;
let scratchTimer = null;
function scratchSound(on) {
  if (!on) {
    clearInterval(scratchTimer);
    scratchTimer = null;
    return;
  }
  if (scratchTimer) return;
  const burst = () => {
    try {
      audio ??= new AudioContext();
      if (audio.state === 'suspended') audio.resume();
      const t0 = audio.currentTime;
      for (let i = 0; i < 4; i++) {
        const len = 0.09;
        const buf = audio.createBuffer(1, Math.floor(audio.sampleRate * len), audio.sampleRate);
        const d = buf.getChannelData(0);
        for (let j = 0; j < d.length; j++) d[j] = (Math.random() * 2 - 1) * (1 - j / d.length);
        const src = audio.createBufferSource();
        src.buffer = buf;
        const filter = audio.createBiquadFilter();
        filter.type = 'bandpass';
        filter.frequency.value = 2400 + Math.random() * 1200;
        const gain = audio.createGain();
        gain.gain.value = 0.25;
        src.connect(filter).connect(gain).connect(audio.destination);
        src.start(t0 + i * 0.14);
      }
    } catch { /* audio not allowed yet */ }
  };
  burst();
  scratchTimer = setInterval(burst, 2200);
}

// ---------- buttons ----------

$('start').onclick = () => send('start', {
  settings: { focusMin: Number($('focusMin').value), breakMin: Number($('breakMin').value) }
});
$('pause').onclick = () => send('pause');
$('resume').onclick = () => send('resume');
$('stop').onclick = () => send('stop');
$('takeBreak').onclick = () => send('takeBreak');

function letOut() {
  releasingUntil = Date.now() + 3200;
  render();
  send('release');
}
$('release').onclick = letOut;
$('endBreak').onclick = letOut;

$('saveSettings').onclick = async () => {
  await send('settings', { settings: readSettings() });
  fillSettings();
  $('saved').textContent = 'Saved ✓';
  setTimeout(() => ($('saved').textContent = ''), 1500);
};
// Night mode only changes when you press its Save button.
$('saveNight').onclick = async () => {
  await send('settings', { settings: {
    nightLock: $('nightLock').checked,
    nightStart: $('nightStart').value || '00:00',
    nightEnd: $('nightEnd').value || '06:00'
  } });
  $('nightSaved').textContent = 'Saved ✓';
  setTimeout(() => ($('nightSaved').textContent = ''), 1500);
};
// Closing the box without saving puts the saved values back.
$('nightBox').ontoggle = () => {
  if ($('nightBox').open || !state) return;
  $('nightLock').checked = state.settings.nightLock;
  $('nightStart').value = state.settings.nightStart;
  $('nightEnd').value = state.settings.nightEnd;
};

$('clearTreats').onclick = () => {
  if (confirm('Empty the treat jar?')) send('clearTreats');
};
$('focusMin').oninput = render;
// ---------- 📌 Float: a small Pork clock on top of every window ----------
// Picture-in-Picture keeps a small video above all windows and apps. Pork's
// room and the clock are drawn into a canvas, and the canvas is that video.
// It has to start from a click on Pork's tab (the popup closes too soon).

let pip = null;

function roomCss() {
  return [...document.styleSheets].map(ss => {
    try { return [...ss.cssRules].map(r => r.cssText).join('\n'); } catch { return ''; }
  }).join('\n');
}

// A picture of the room as it looks now (redrawn when Pork's pose changes).
function roomPicture() {
  const key = app.dataset.pose + (app.dataset.goal != null) + $('bubbleText').textContent;
  if (pip.roomKey === key) return pip.room;
  pip.roomKey = key;
  const svg = $('room').cloneNode(true);
  svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
  svg.setAttribute('width', '720');
  svg.setAttribute('height', '400');
  svg.setAttribute('data-pose', app.dataset.pose);
  if (app.dataset.goal != null) svg.setAttribute('data-goal', '');
  const style = document.createElementNS('http://www.w3.org/2000/svg', 'style');
  style.textContent = roomCss();
  svg.insertBefore(style, svg.firstChild);
  const img = new Image();
  img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(new XMLSerializer().serializeToString(svg));
  pip.room = img;
  return img;
}

function drawFloat() {
  const { ctx, canvas } = pip;
  const W = canvas.width;
  const H = canvas.height;
  const dark = matchMedia('(prefers-color-scheme: dark)').matches;
  ctx.fillStyle = dark ? '#4a3f35' : '#f6e7cf';
  ctx.fillRect(0, 0, W, H);
  const room = roomPicture();
  if (room.complete && room.naturalWidth) ctx.drawImage(room, 0, 0, W, H);

  // Clock band across the top.
  ctx.fillStyle = 'rgba(25, 20, 16, .72)';
  ctx.fillRect(0, 0, W, 92);
  const phase = app.dataset.phase;
  const color = phase === 'overtime' ? '#ff6b61'
    : phase === 'break' ? '#8fbfff'
    : app.dataset.goal != null ? '#f2c14e' : '#ffffff';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#d8cfc4';
  ctx.font = '600 15px -apple-system, BlinkMacSystemFont, sans-serif';
  ctx.fillText($('label').textContent.toUpperCase(), 18, 20);
  ctx.fillStyle = color;
  ctx.font = '800 54px -apple-system, BlinkMacSystemFont, sans-serif';
  ctx.fillText($('time').textContent, 16, 60);
  if (!$('treatChip').hidden) {
    ctx.font = '40px -apple-system, "Apple Color Emoji", sans-serif';
    ctx.textAlign = 'right';
    ctx.fillText($('chipTreat').textContent, W - 130, 50);
    ctx.fillStyle = '#d8cfc4';
    ctx.font = '600 14px -apple-system, BlinkMacSystemFont, sans-serif';
    ctx.fillText('treat after', W - 18, 34);
    ctx.fillStyle = '#ffffff';
    ctx.font = '800 26px -apple-system, BlinkMacSystemFont, sans-serif';
    ctx.fillText($('chipTime').textContent, W - 18, 62);
    ctx.textAlign = 'left';
  }
}

function setupFloat() {
  if (pip) return pip;
  const canvas = document.createElement('canvas');
  canvas.width = 480;
  canvas.height = 267;
  const video = document.createElement('video');
  video.id = 'pipVideo';
  video.muted = true;
  video.playsInline = true;
  document.body.appendChild(video);
  pip = { canvas, ctx: canvas.getContext('2d'), video, room: null, roomKey: null };
  drawFloat();
  video.srcObject = canvas.captureStream(4);
  setInterval(drawFloat, 500);
  return pip;
}

// Fallback: a small separate Safari window with just the clock and the room.
function openMiniWindow() {
  api.windows.create({ url: api.runtime.getURL('app.html?tab=1&mini=1'), type: 'popup', width: 360, height: 330 })
    .catch(() => {});
}

async function startFloat() {
  setupFloat();
  const v = pip.video;
  try {
    if (document.pictureInPictureElement) {
      await document.exitPictureInPicture();
      return;
    }
    await v.play();
    if (v.requestPictureInPicture) await v.requestPictureInPicture();
    else if (v.webkitSupportsPresentationMode?.('picture-in-picture')) v.webkitSetPresentationMode('picture-in-picture');
    else throw new Error('no Picture-in-Picture');
    $('floatPrompt').hidden = true;
    $('floatBtn').classList.remove('glow');
  } catch {
    openMiniWindow();
  }
}

if (isTab) {
  $('floatBtn').onclick = startFloat;
  if (params.has('float')) {
    $('floatPrompt').hidden = false;
    $('floatBtn').classList.add('glow');
  }
  api.runtime.onMessage.addListener(msg => {
    if (msg && msg.cmd === 'floatPrompt') {
      $('floatPrompt').hidden = false;
      $('floatBtn').classList.add('glow');
    }
  });
} else {
  // In the toolbar popup: go to Pork's tab, where one click starts floating.
  $('floatBtn').onclick = async () => {
    const base = api.runtime.getURL('app.html');
    const tabs = await api.tabs.query({}).catch(() => []);
    const tab = tabs.find(t => (t.url || '').startsWith(base) && t.url.includes('tab=1'));
    if (tab) {
      await api.tabs.update(tab.id, { active: true }).catch(() => {});
      await api.windows?.update(tab.windowId, { focused: true }).catch(() => {});
      api.runtime.sendMessage({ cmd: 'floatPrompt' }).catch(() => {});
    } else {
      await api.tabs.create({ url: api.runtime.getURL('app.html?tab=1&float=1') }).catch(() => {});
    }
    window.close();
  };
}

$('openTab').onclick = e => {
  e.preventDefault();
  api.tabs.create({ url: api.runtime.getURL('app.html?tab=1') });
  window.close();
};

api.storage.onChanged.addListener((changes, area) => {
  if (area === 'local' && changes[KEY]?.newValue) setState(changes[KEY].newValue);
});

send('sync');
setInterval(render, 250);
