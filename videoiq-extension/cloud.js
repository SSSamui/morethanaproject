// VideoIQ — cloud.js
// Simple no-account cloud sync via Supabase REST API.
// Anyone can post notes publicly with just a display name.

window.VIQ_CLOUD = (() => {
  'use strict';

  const { supabaseUrl, supabaseKey } = VIQ_CONFIG;
  const TABLE = '/rest/v1/danmu_posts';

  async function req(path, opts = {}) {
    const res = await fetch(supabaseUrl + path, {
      ...opts,
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer ' + supabaseKey,
        'Prefer': opts.prefer || '',
        ...(opts.headers || {})
      }
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || err.hint || res.statusText);
    }
    const text = await res.text();
    return text ? JSON.parse(text) : null;
  }

  // Post this user's notes for a video publicly
  async function postNotes({ videoId, videoTitle, authorName, color, notes }) {
    return req(TABLE, {
      method: 'POST',
      prefer: 'return=representation',
      body: JSON.stringify({
        video_id:    videoId,
        video_title: videoTitle || '',
        author_name: authorName || 'Anonymous',
        color:       color || '#4f9eff',
        notes:       notes,
        is_public:   true
      })
    });
  }

  // Get all public posts for a video — returns array of post objects
  async function getPostsForVideo(videoId) {
    return req(
      TABLE +
      '?video_id=eq.' + encodeURIComponent(videoId) +
      '&is_public=eq.true' +
      '&select=id,author_name,color,notes,posted_at' +
      '&order=posted_at.asc'
    );
  }

  // Check if Supabase is configured (non-placeholder values)
  function isConfigured() {
    return supabaseUrl && !supabaseUrl.includes('YOUR_PROJECT');
  }

  return { postNotes, getPostsForVideo, isConfigured };
})();
