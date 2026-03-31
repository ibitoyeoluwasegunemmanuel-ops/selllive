// ============================================================
// SELLLIVE BACKEND — server.js
// Main entry point for the Express API
// ============================================================

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

// Route imports
const authRoutes = require('./routes/auth');
const streamRoutes = require('./routes/streams');
const orderRoutes = require('./routes/orders');
const paymentRoutes = require('./routes/payments');
const sellerRoutes = require('./routes/sellers');
const buyerRoutes = require('./routes/buyers');

const app = express();
const PORT = process.env.PORT || 3000;

// ============================================================
// MIDDLEWARE
// ============================================================

// Security headers
app.use(helmet());

// CORS — allow Flutter web and mobile
app.use(cors({
  origin: [
    process.env.FRONTEND_URL,
    'http://localhost:3000',
    'http://localhost:5000',
    'http://localhost:8080',  // Flutter web dev server
  ],
  credentials: true,
}));

// Logging
app.use(morgan('dev'));

// Parse JSON bodies
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Rate limiting — prevent abuse
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,                  // 100 requests per window
  message: { error: 'Too many requests, please slow down.' }
});
app.use('/api/', limiter);

// Stricter limit for auth endpoints
const authLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 10,                   // 10 OTP requests per hour
  message: { error: 'Too many auth attempts. Try again in an hour.' }
});
app.use('/api/auth/', authLimiter);

// ============================================================
// ROUTES
// ============================================================

// Health check (for Render/Railway deployment)
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    app: 'SellLive API',
    time: new Date().toISOString(),
  });
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/streams', streamRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/sellers', sellerRoutes);
app.use('/api/buyers', buyerRoutes);

// Flutterwave webhook (no rate limiting — it's from Flutterwave's servers)
app.use('/webhook/flutterwave', paymentRoutes);

// ============================================================
// ERROR HANDLING
// ============================================================

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('❌ Error:', err.message);
  console.error(err.stack);

  res.status(err.status || 500).json({
    error: err.message || 'Something went wrong on our end.',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
});

// ============================================================
// START SERVER
// ============================================================
app.listen(PORT, () => {
  console.log(`
  ╔═══════════════════════════════════╗
  ║   🔴 SellLive API is running       ║
  ║   Port: ${PORT}                       ║
  ║   Mode: ${process.env.NODE_ENV}            ║
  ╚═══════════════════════════════════╝
  `);
});

module.exports = app;
