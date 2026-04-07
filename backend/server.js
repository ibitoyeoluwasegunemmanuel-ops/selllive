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
const adminRoutes = require('./routes/admin');
const walletRoutes = require('./routes/wallet');
const { router: notificationRoutes, notifyFollowers } = require('./routes/notifications');
const { router: waRouter, notifyOrderPaid } = require('./routes/whatsapp');
const logisticsRoutes = require('./routes/logistics');
const loyaltyRoutes = require('./routes/loyalty');
const verificationRoutes = require('./routes/verification');
const uploadsRoutes = require('./routes/uploads');
const exploreRoutes = require('./routes/explore');
const feedRoutes = require('./routes/feed');
const chatRoutes = require('./routes/chat');
const featuresRoutes = require('./routes/features');
const webhookRoutes = require('./routes/webhook');
const reviewsRoutes = require('./routes/reviews');
const notifRoutes = require('./routes/notifications_route');

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
app.use('/api/admin', adminRoutes);
app.use('/api/wallet', walletRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/uploads', uploadsRoutes);
app.use('/api/explore', exploreRoutes);
app.use('/api/feed', feedRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/features', featuresRoutes);
app.use('/webhook', webhookRoutes);
app.use('/api/reviews', reviewsRoutes);
app.use('/api/notifications', notifRoutes);
app.use('/api/whatsapp', waRouter);
app.use('/api/logistics', logisticsRoutes);
app.use('/api/loyalty', loyaltyRoutes);
app.use('/api/verification', verificationRoutes);

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
// Vercel exports the app as a serverless function
// Local dev uses app.listen
// ============================================================
if (process.env.NODE_ENV !== 'production') {
  app.listen(PORT, () => {
    console.log(`
  ╔═══════════════════════════════════╗
  ║   🔴 SellLive API is running       ║
  ║   Port: ${PORT}                       ║
  ║   Mode: ${process.env.NODE_ENV}            ║
  ╚═══════════════════════════════════╝
    `);
  });
}

module.exports = app;

