// Puppy Pomodoro — popup and tab page. The background worker owns the
// timer; this page draws it and sends commands.

const api = globalThis.browser ?? globalThis.chrome;
const KEY = 'pp';
const $ = id => document.getElementById(id);

const params = new URLSearchParams(location.search);
const isTab = params.has('tab');
if (isTab) document.body.classList.add('tab');

const app = $('app');
let state = null;
let releasingUntil = 0;
let seenPlants = null;
let lastSync = 0;

if (params.get('blocked')) {
  $('blocked').hidden = false;
  $('blocked').textContent = `🐶 No ${params.get('blocked')} during focus — the puppy is napping, keep going!`;
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
  const first = !state;
  const r = s.lastRelease;
  if (!first && r && r.at !== state.lastRelease?.at && Date.now() - r.at < 3000) {
    releasingUntil = Math.max(releasingUntil, r.at + 3200);
  }
  state = s;
  if (r) $('outsidePlant').textContent = r.plant;
  if (first) fillSettings();
  renderGarden();
  render();
}

function fillSettings() {
  const st = state.settings;
  $('focusMin').value = st.focusMin;
  $('breakMin').value = st.breakMin;
  $('autoBreak').checked = st.autoBreak;
  $('blockDuringFocus').checked = st.blockDuringFocus;
  $('openTab2').checked = st.openTab;
  $('sound').checked = st.sound;
  $('sites').value = st.sites.join('\n');
}

function readSettings() {
  return {
    focusMin: Number($('focusMin').value),
    breakMin: Number($('breakMin').value),
    autoBreak: $('autoBreak').checked,
    blockDuringFocus: $('blockDuringFocus').checked,
    openTab: $('openTab2').checked,
    sound: $('sound').checked,
    sites: $('sites').value.split(/[\s,]+/)
  };
}

function render() {
  if (!state) return;
  const now = Date.now();
  const s = state;
  const left = s.paused ? s.remaining : s.endsAt ? s.endsAt - now : 0;

  // The worker may be asleep; nudge it if a phase should have ended.
  if (!s.paused && s.endsAt && left <= 0 && now - lastSync > 1000) {
    lastSync = now;
    send('sync');
  }

  app.dataset.phase = s.phase;
  if (s.paused) app.dataset.paused = '';
  else delete app.dataset.paused;

  let label, time, sub = '';
  switch (s.phase) {
    case 'focus':
      label = s.paused ? 'Focus · paused' : 'Focus';
      time = fmt(Math.max(0, left));
      if (s.extraMs > 0) sub = `${fmt(s.settings.focusMin * 60000)} + ${fmt(s.extraMs)} extra from the long break`;
      break;
    case 'break':
      label = s.paused ? 'Break · paused' : 'Break';
      time = fmt(Math.max(0, left));
      sub = 'Puppy is playing 🎾';
      break;
    case 'overtime':
      label = 'Break is over!';
      time = '−' + fmt(now - s.overtimeFrom);
      sub = 'Puppy is scratching the door. This time gets added to your next focus.';
      break;
    default:
      label = 'Ready to focus';
      time = fmt(Number($('focusMin').value || s.settings.focusMin) * 60000);
      sub = s.sessions ? `${s.sessions} focus session${s.sessions > 1 ? 's' : ''} done` : '';
  }
  $('label').textContent = label;
  $('time').textContent = time;
  $('sub').textContent = sub;

  let scene = 'sleep';
  if (now < releasingUntil) scene = 'out';
  else if (s.phase === 'break') scene = 'play';
  else if (s.phase === 'overtime') scene = 'door';
  app.dataset.scene = scene;

  document.title = s.phase === 'idle' ? 'Puppy Pomodoro' : `${time} · ${label}`;
  scratchSound(scene === 'door' && s.settings.sound);
}

function renderGarden() {
  const g = state.garden;
  const box = $('plants');
  const known = seenPlants;
  box.textContent = '';
  for (const p of g) {
    const el = document.createElement('span');
    el.textContent = p.plant;
    const late = p.overtimeMs > 0 ? `, ${fmt(p.overtimeMs)} late` : ', right on time';
    el.title = new Date(p.at).toLocaleString() + late;
    if (known !== null && !known.has(p.at)) el.className = 'new';
    box.appendChild(el);
  }
  seenPlants = new Set(g.map(p => p.at));
  $('gardenCount').textContent = g.length ? `${g.length} planted` : 'nothing planted yet';
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

$('start').onclick = () => send('start', { settings: readSettings() });
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
$('clearGarden').onclick = () => {
  if (confirm('Remove every plant from your forest?')) send('clearGarden');
};
$('focusMin').oninput = render;
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
