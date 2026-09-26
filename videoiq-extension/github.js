// VideoIQ — github.js
// Saves danmu to a GitHub repo through the REST "contents" API.
// Everyone's danmu live in ONE shared repo. Each person (by their danmu name)
// writes ONLY their own file, so people never overwrite each other:
//
//   danmu/<videoId>/<name>.json
//
// Only the repo owner needs a GitHub account: friends can use a token the owner
// made for that one repo. Everyone reads all files in danmu/<videoId>/.

window.VIQ_GH = (() => {
  'use strict';

  const API    = 'https://api.github.com';
  const ROOT   = 'danmu';
  const CFG_KEY = 'videoiq_github';   // kept apart from settings so the token never ends up in exports

  // author = danmu name used for our file; login = GitHub account the token belongs to
  let cfg  = { repo: '', branch: '', token: '', login: '', author: '' };
  const shaCache = {};                // path → blob sha of our last known version

  function load() {
    return new Promise(res => chrome.storage.local.get([CFG_KEY], r => {
      cfg = Object.assign(cfg, r[CFG_KEY] || {});
      if (!cfg.author && cfg.login) cfg.author = cfg.login;   // configs saved by v3.2
      res(cfg);
    }));
  }
  function persist() { chrome.storage.local.set({ [CFG_KEY]: cfg }); }

  function isConfigured() { return !!(cfg.repo && cfg.token && cfg.author); }
  function getConfig()    { return Object.assign({}, cfg); }

  async function req(path, opts = {}) {
    const res = await fetch(API + path, {
      ...opts,
      cache: 'no-store',   // GitHub caches contents for 60s; we want the other person's latest
      headers: {
        'Accept': opts.accept || 'application/vnd.github+json',
        'Authorization': 'Bearer ' + cfg.token,
        'X-GitHub-Api-Version': '2022-11-28',
        ...(opts.body ? { 'Content-Type': 'application/json' } : {})
      }
    });
    if (res.status === 404 && opts.allow404) return null;
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      const e = new Error(err.message || res.statusText);
      e.status = res.status;
      throw e;
    }
    const ct = res.headers.get('content-type') || '';
    return ct.includes('json') ? res.json() : res.text();
  }

  const repoPath = () => '/repos/' + cfg.repo.split('/').map(encodeURIComponent).join('/');
  const refQ     = (sep) => cfg.branch ? sep + 'ref=' + encodeURIComponent(cfg.branch) : '';
  const filePath = (videoId, author) =>
    ROOT + '/' + encodeURIComponent(videoId) + '/' + encodeURIComponent(author) + '.json';

  // UTF-8 safe base64 (danmu contain emoji / Chinese)
  function b64encode(str) {
    const bytes = new TextEncoder().encode(str);
    let bin = '';
    for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
    return btoa(bin);
  }
  function b64decode(b64) {
    const bin = atob(b64.replace(/\s/g, ''));
    return new TextDecoder().decode(Uint8Array.from(bin, c => c.charCodeAt(0)));
  }

  // Verify token + repo access, remember who we are
  async function connect({ repo, branch, token, author }) {
    cfg = { repo: repo.trim().replace(/^https:\/\/github\.com\//, '').replace(/\/+$/, ''),
            branch: (branch || '').trim(), token: token.trim(), login: '', author: (author || '').trim() };
    if (!cfg.author || cfg.author === 'Me') throw new Error('Type your own name in "Your name" first — it names your file, so each person must use a different name');
    if (!/^[\w.-]+\/[\w.-]+$/.test(cfg.repo)) throw new Error('Repo must look like owner/name, e.g. yourGitHubName/danmu-data');
    if (!cfg.token) throw new Error('Paste your GitHub token first (it starts with ghp_ or github_pat_)');
    if (!/^(ghp_|github_pat_|gho_|ghu_)/.test(cfg.token))
      throw new Error('That does not look like a GitHub token — it should start with ghp_ (classic) or github_pat_ (fine-grained)');

    let me;
    try { me = await req('/user'); }
    catch (e) {
      if (e.status === 401) throw new Error('GitHub rejected this token (Bad credentials). It may be copied incompletely, expired, or deleted — create a new one and paste the whole thing.');
      throw e;
    }
    let r;
    try { r = await req(repoPath()); }
    catch (e) {
      if (e.status === 404) throw new Error('Signed in as @' + me.login + ', but repo "' + cfg.repo + '" was not found. ' +
        'The part before "/" must be the GitHub username of the repo\'s owner, the repo must exist, and this token must be allowed to access it.');
      throw e;
    }
    if (r.permissions && !r.permissions.push) throw new Error('This token can read ' + cfg.repo + ' but cannot write to it — use a token with Contents: Read and write.');
    cfg.login = me.login;
    persist();
    return cfg.author;
  }

  function disconnect() {
    cfg = { repo: '', branch: '', token: '', login: '', author: '' };
    persist();
  }

  // List every person's file for a video. Returns [{login: <name>, sha, path}]
  async function listVideo(videoId) {
    const dir = await req(repoPath() + '/contents/' + ROOT + '/' + encodeURIComponent(videoId) + refQ('?'),
                          { allow404: true });
    if (!Array.isArray(dir)) return [];
    return dir.filter(f => f.type === 'file' && f.name.endsWith('.json'))
              .map(f => ({ login: decodeURIComponent(f.name.slice(0, -5)), sha: f.sha, path: f.path }));
  }

  async function readFile(path) {
    const f = await req(repoPath() + '/contents/' + path.split('/').map(encodeURIComponent).join('/') + refQ('?'),
                        { allow404: true });
    if (!f) return null;
    shaCache[path] = f.sha;
    return JSON.parse(b64decode(f.content));
  }

  // Write (create or replace) our own file for a video
  async function saveMine(videoId, doc) {
    const path = filePath(videoId, cfg.author);
    const put = () => req(repoPath() + '/contents/' + path, {
      method: 'PUT',
      body: JSON.stringify({
        message: 'danmu: ' + cfg.author + ' updated ' + videoId,
        content: b64encode(JSON.stringify(doc, null, 2)),
        ...(shaCache[path] ? { sha: shaCache[path] } : {}),
        ...(cfg.branch ? { branch: cfg.branch } : {})
      })
    });
    let out;
    try { out = await put(); }
    catch (e) {
      // sha missing/stale (first save, or another tab/device saved) → refresh sha, retry once
      if (e.status !== 409 && e.status !== 422) throw e;
      const cur = await req(repoPath() + '/contents/' + path + refQ('?'), { allow404: true });
      shaCache[path] = cur ? cur.sha : undefined;
      out = await put();
    }
    shaCache[path] = out.content.sha;
    return out;
  }

  load();
  return { load, connect, disconnect, isConfigured, getConfig, listVideo, readFile, saveMine, filePath };
})();
