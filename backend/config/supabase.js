// config/supabase.js — Supabase client for backend use
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY  // service key = full access (backend only!)
);

module.exports = supabase;
