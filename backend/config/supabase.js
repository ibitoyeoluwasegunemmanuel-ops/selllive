// config/supabase.js — Supabase client configured for Vercel serverless
const { createClient } = require('@supabase/supabase-js');

// On Vercel, the X-Forwarded-For header causes validation errors with
// supabase-js. We pass db: { schema: 'public' } and disable auth persistence
// to avoid the header validation issue in serverless environments.
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
    db: {
      schema: 'public',
    },
    global: {
      fetch: (url, options = {}) => {
        // Strip X-Forwarded-For to avoid Supabase validation error on Vercel
        const headers = { ...(options.headers || {}) };
        delete headers['X-Forwarded-For'];
        delete headers['x-forwarded-for'];
        return fetch(url, { ...options, headers });
      },
    },
  }
);

module.exports = supabase;
