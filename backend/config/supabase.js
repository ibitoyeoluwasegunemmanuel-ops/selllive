// config/supabase.js
// Uses anon key — RLS disabled for MVP backend operations
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL  = process.env.SUPABASE_URL  || 'https://aayprwxhzbhmghvgaeyi.supabase.co';
// Use service key if available, otherwise fall back to anon key (RLS disabled)
const SUPABASE_KEY  = process.env.SUPABASE_SERVICE_KEY
  || process.env.SUPABASE_ANON_KEY
  || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFheXByd3hoemJobWdodmdhZXlpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MjM4NzIsImV4cCI6MjA5MDQ5OTg3Mn0.zXpJT9lqmpnPmEFaZTfWg1k8Iq4_yLfyhMLGQxf6qJ0';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

module.exports = supabase;
