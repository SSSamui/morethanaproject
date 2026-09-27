// VideoIQ — cloud.js
// Everyone's danmu in ONE Supabase database, with real accounts (email + password).
//
//   profiles : one row per account  (display_name is unique, color)
//   danmu    : one row per danmu    (user_id, client_id, video_id, time_sec, text, style…)
//
// Anyone can READ danmu; only a signed-in user can write, and only their own rows
// (enforced by row-level security in the database — see SETUP.md).

window.VIQ_CLOUD = (() => {
  'use strict';

  const { supabaseUrl, supabaseKey } = VIQ_CONFIG;
  const AUTH_KEY = 'videoiq_auth';

  // { access_token, refresh_token, expires_at (unix s), user: {id, email} }
  let session = null;
  let profile = null;          // { id, display_name, color }
  let refreshing = null;
  const listeners = new Set();

  function isConfigured() {
    return !!(supabaseUrl && supabaseKey && !supabaseUrl.includes('YOUR_PROJECT') && !supabaseKey.includes('YOUR_'));
  }
  const isSignedIn = () => !!(session && profile);
  const getUser    = () => isSignedIn() ? { id: session.user.id, email: session.user.email, name: profile.display_name, color: profile.color } : null;
  const onChange   = fn => listeners.add(fn);
  const emit       = () => listeners.forEach(fn => { try { fn(getUser()); } catch (e) { console.warn(e); } });

  // Session storage: chrome.storage inside the extension, localStorage on the web page
  const hasChrome = typeof chrome !== 'undefined' && chrome.storage && chrome.storage.local;
  const store = hasChrome ? {
    get: k => new Promise(r => chrome.storage.local.get([k], x => r(x[k] || null))),
    set: (k, v) => chrome.storage.local.set({ [k]: v })
  } : {
    get: async k => { try { return JSON.parse(localStorage.getItem(k)); } catch { return null; } },
    set: (k, v) => { try { localStorage.setItem(k, JSON.stringify(v)); } catch { /* private mode */ } }
  };
  function persist() { store.set(AUTH_KEY, session); }

  // ── low-level fetch ────────────────────────────────────────────────────────
  async function call(path, { method = 'GET', body, auth = false, prefer, anon = false } = {}) {
    const headers = { 'apikey': supabaseKey };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (prefer) headers['Prefer'] = prefer;
    if (auth || (!anon && session)) {
      await ensureFresh();
      if (session) headers['Authorization'] = 'Bearer ' + session.access_token;
      else if (auth) throw new Error('Please sign in first');
    }
    const res = await fetch(supabaseUrl + path, {
      method, headers, cache: 'no-store',
      body: body === undefined ? undefined : JSON.stringify(body)
    });
    const text = await res.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch { data = text; }
    if (!res.ok) {
      const msg = (data && (data.error_description || data.msg || data.message || data.error)) || res.statusText;
      const e = new Error(friendly(msg, data && data.code));
      e.status = res.status; e.code = data && data.code;
      throw e;
    }
    return data;
  }

  function friendly(msg, code) {
    const m = String(msg);
    if (code === '23505' || /duplicate key|profiles_name_unique/i.test(m)) return 'That name is already taken — pick another one';
    if (/Database error saving new user/i.test(m)) return 'Could not create the account — that name may already be taken';
    if (/Invalid login credentials/i.test(m)) return 'Wrong email or password';
    if (/Email not confirmed/i.test(m)) return 'Please confirm your email first (check your inbox), then sign in';
    if (/User already registered/i.test(m)) return 'An account with this email already exists — sign in instead';
    if (/Token has expired or is invalid|otp_expired|invalid.*otp/i.test(m)) return 'That code is wrong or has expired — check the newest email, or press "Send a new code"';
    if (/rate limit/i.test(m)) return 'Too many emails were sent recently — please wait a few minutes and try again';
    if (/For security purposes, you can only request this after/i.test(m)) return 'Please wait a minute before asking for another code';
    return m;
  }

  // ── session handling ───────────────────────────────────────────────────────
  function setSession(s) {
    session = s ? {
      access_token: s.access_token, refresh_token: s.refresh_token,
      expires_at: s.expires_at || Math.floor(Date.now() / 1000) + (s.expires_in || 3600),
      user: { id: s.user.id, email: s.user.email }
    } : null;
    persist();
  }

  async function ensureFresh() {
    if (!session) return;
    if (session.expires_at * 1000 - Date.now() > 60_000) return;
    if (!refreshing) refreshing = (async () => {
      try {
        const s = await fetch(supabaseUrl + '/auth/v1/token?grant_type=refresh_token', {
          method: 'POST', headers: { 'apikey': supabaseKey, 'Content-Type': 'application/json' },
          body: JSON.stringify({ refresh_token: session.refresh_token })
        });
        if (!s.ok) throw new Error('refresh failed');
        setSession(await s.json());
      } catch (e) {
        // Refresh token no longer valid → signed out
        session = null; profile = null; persist(); emit();
      } finally { refreshing = null; }
    })();
    await refreshing;
  }

  async function loadProfile() {
    const rows = await call('/rest/v1/profiles?id=eq.' + session.user.id + '&select=id,display_name,color', { auth: true });
    profile = rows && rows[0] || null;
    if (!profile) throw new Error('Your profile is missing — was the SQL in SETUP.md run completely?');
  }

  // Restore a saved session (called once at startup)
  async function init() {
    if (!isConfigured()) return null;
    const saved = await store.get(AUTH_KEY);
    if (!saved) return null;
    session = saved;
    try { await ensureFresh(); if (session) await loadProfile(); }
    catch (e) { console.warn('VideoIQ: could not restore session:', e.message); if (e.status === 401) { session = null; persist(); } }
    return getUser();
  }

  // ── accounts ───────────────────────────────────────────────────────────────
  function checkName(name) {
    name = (name || '').trim();
    if (!name || name === 'Me') throw new Error('Pick a display name (not "Me")');
    if (name.length > 30) throw new Error('Name must be 30 characters or less');
    return name;
  }

  async function nameTaken(name) {
    const esc = name.replace(/([%_\\])/g, '\\$1');
    const rows = await call('/rest/v1/profiles?select=id&display_name=ilike.' + encodeURIComponent(esc), { anon: true });
    return Array.isArray(rows) && rows.some(r => !session || r.id !== session.user.id);
  }

  async function signUp({ email, password, name, color }) {
    name = checkName(name);
    if (await nameTaken(name)) throw new Error('That name is already taken — pick another one');
    const data = await call('/auth/v1/signup', {
      method: 'POST', anon: true,
      body: { email: email.trim(), password, data: { display_name: name, color: /^#[0-9a-f]{6}$/i.test(color) ? color : '#4f9eff' } }
    });
    if (data && data.access_token) {         // email confirmation is off → signed in right away
      setSession(data); await loadProfile(); emit();
      return { signedIn: true };
    }
    return { signedIn: false };             // confirmation email sent
  }

  async function signIn({ email, password }) {
    const data = await call('/auth/v1/token?grant_type=password', {
      method: 'POST', anon: true, body: { email: email.trim(), password }
    });
    setSession(data);
    await loadProfile();
    emit();
    return getUser();
  }

  // Confirm a new account with the 6-digit code from the confirmation email
  async function verifyEmailCode({ email, code }) {
    const token = String(code).replace(/\s/g, '');
    if (!/^\d{6,10}$/.test(token)) throw new Error('Enter the code from the email (only digits)');
    let data;
    try {
      data = await call('/auth/v1/verify', { method: 'POST', anon: true, body: { type: 'email', email: email.trim(), token } });
    } catch (e) {
      // older projects only accept the "signup" type for sign-up confirmations
      data = await call('/auth/v1/verify', { method: 'POST', anon: true, body: { type: 'signup', email: email.trim(), token } });
    }
    if (!data || !data.access_token) throw new Error('Confirmation did not return a session — try signing in');
    setSession(data);
    await loadProfile();
    emit();
    return getUser();
  }

  function resendCode(email) {
    return call('/auth/v1/resend', { method: 'POST', anon: true, body: { type: 'signup', email: email.trim() } });
  }

  async function signOut() {
    try { if (session) await call('/auth/v1/logout', { method: 'POST', auth: true }); } catch { /* token may already be gone */ }
    session = null; profile = null; persist(); emit();
  }

  async function updateProfile(fields) {
    const patch = {};
    if (fields.name !== undefined) {
      patch.display_name = checkName(fields.name);
      if (patch.display_name.toLowerCase() !== profile.display_name.toLowerCase() && await nameTaken(patch.display_name))
        throw new Error('That name is already taken — pick another one');
    }
    if (fields.color !== undefined) patch.color = fields.color;
    const rows = await call('/rest/v1/profiles?id=eq.' + session.user.id, {
      method: 'PATCH', auth: true, prefer: 'return=representation', body: patch
    });
    if (rows && rows[0]) profile = rows[0];
    emit();
    return getUser();
  }

  // ── danmu ──────────────────────────────────────────────────────────────────
  // All danmu on a video, everyone's, with the author's current name + color
  // ── Privacy view ───────────────────────────────────────────────────────────
  // With privacy.sql applied, danmu are read through `danmu_public`, which leaves out
  // the author of hidden-name danmu for everyone except the writer and the one person
  // they chose. Without it (older database) we fall back to the table.
  let hasView = null;                      // null = not checked yet
  const nameCache = new Map();             // user id → display name (for "only visible to …")

  function isMissingView(e) {
    return e.status === 404 || e.code === 'PGRST205' || e.code === '42P01' || /danmu_public|schema cache/i.test(e.message);
  }

  // Same shape for both paths:
  // {user_id, client_id, time_sec, text, style, is_summary, updated_at, video_id, video_title,
  //  profiles:{display_name,color}|null, name_hidden, name_revealed, name_to:[{id,name}]}
  function normalize(r) {
    if ('name_hidden' in r) {              // from the view
      return Object.assign(r, {
        profiles: r.user_id ? { display_name: r.display_name, color: r.color } : null,
        name_hidden: !!r.name_hidden, name_revealed: !!r.name_revealed,
        name_to: (r.name_visible_to || []).map(id => ({ id, name: nameCache.get(id) || '' }))
      });
    }
    const me = session && session.user.id;  // older database: can only hide on screen
    return Object.assign(r, {
      name_hidden: !!(r.style && r.style.anon) && r.user_id !== me, name_revealed: false, name_to: []
    });
  }

  async function fillNames(rows) {
    const ids = [...new Set(rows.flatMap(r => r.name_visible_to || []))].filter(id => !nameCache.has(id));
    if (ids.length) {
      try {
        const ps = await call('/rest/v1/profiles?select=id,display_name&id=in.(' + ids.join(',') + ')');
        (ps || []).forEach(p => nameCache.set(p.id, p.display_name));
      } catch { /* names are cosmetic */ }
    }
  }

  async function readDanmu(viewQuery, tableQuery) {
    if (hasView !== false) {
      try {
        const rows = (await call('/rest/v1/danmu_public?' + viewQuery)) || [];
        hasView = true;
        await fillNames(rows);
        return rows.map(normalize);
      } catch (e) {
        if (!isMissingView(e)) throw e;
        hasView = false;
      }
    }
    return ((await call('/rest/v1/danmu?' + tableQuery)) || []).map(normalize);
  }

  const VIEW_COLS = 'user_id,client_id,video_id,video_title,time_sec,text,style,is_summary,updated_at,' +
                    'display_name,color,name_hidden,name_revealed,name_visible_to';
  const TABLE_COLS = 'user_id,client_id,video_id,video_title,time_sec,text,style,is_summary,updated_at,profiles(display_name,color)';

  // All danmu on a video, everyone's
  function getVideo(videoId) {
    const q = 'video_id=eq.' + encodeURIComponent(videoId) + '&order=time_sec.asc&limit=10000';
    return readDanmu('select=' + VIEW_COLS + '&' + q, 'select=' + TABLE_COLS + '&' + q);
  }

  // Most recent danmu from everyone, across all videos (for the "New danmu" feed)
  function getRecent(limit) {
    const q = 'order=updated_at.desc&limit=' + (limit || 300);
    return readDanmu('select=' + VIEW_COLS + '&' + q, 'select=' + TABLE_COLS + '&' + q);
  }

  // Is "show my name to one person only" available? (privacy.sql applied)
  async function privacyReady() {
    if (hasView === null) {
      try { await call('/rest/v1/danmu_public?select=client_id&limit=1'); hasView = true; }
      catch (e) { if (isMissingView(e)) hasView = false; else throw e; }
    }
    return hasView;
  }

  // Find someone by their display name → {id, name}
  async function findUser(name) {
    name = String(name || '').trim();
    if (!name) throw new Error('Type the person\'s display name');
    const esc = name.replace(/([%_\\*])/g, '\\$1');
    const rows = await call('/rest/v1/profiles?select=id,display_name&display_name=ilike.' + encodeURIComponent(esc));
    const u = (rows || [])[0];
    if (!u) throw new Error('No one is called "' + name + '"');
    if (session && u.id === session.user.id) throw new Error('That\'s you. Pick someone else');
    nameCache.set(u.id, u.display_name);
    return { id: u.id, name: u.display_name };
  }

  // Create or update our own danmu (idempotent on user_id + client_id).
  // n.nameTo = {id,name} → with a hidden name, only that person may see who wrote it.
  async function upsert(videoId, videoTitle, notes) {
    if (!notes.length) return;
    const withTargets = await privacyReady().catch(() => false);
    const anyTarget = notes.some(n => n.nameTo && n.style && n.style.anon);
    if (anyTarget && !withTargets) throw new Error('"Only one person" needs the database update (privacy.sql). Ask the owner to run it');
    return call('/rest/v1/danmu?on_conflict=user_id,client_id', {
      method: 'POST', auth: true, prefer: 'resolution=merge-duplicates,return=minimal',
      body: notes.map(n => Object.assign({
        user_id: session.user.id,
        client_id: n.id,
        video_id: videoId,
        video_title: (videoTitle || '').slice(0, 300) || null,
        time_sec: Math.max(0, Math.floor(n.time || 0)),
        text: String(n.text).slice(0, 500),
        style: n.style ? Object.assign({}, n.style, { nameTo: undefined }) : null,
        is_summary: !!n.isSummary
      }, withTargets ? { name_visible_to: n.nameTo && n.style && n.style.anon ? [n.nameTo.id] : null } : {}))
    });
  }

  function remove(clientIds) {
    if (!clientIds.length) return Promise.resolve();
    return call('/rest/v1/danmu?user_id=eq.' + session.user.id + '&client_id=in.(' + clientIds.map(Number).join(',') + ')', {
      method: 'DELETE', auth: true, prefer: 'return=minimal'
    });
  }

  return { isConfigured, init, isSignedIn, getUser, onChange,
           signUp, signIn, signOut, updateProfile, verifyEmailCode, resendCode,
           getVideo, getRecent, upsert, remove, findUser, privacyReady };
})();
