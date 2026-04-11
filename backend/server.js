// ============================================================
// SELLLIVE BACKEND — server.js
// ============================================================
require('dotenv').config();
const express = require('express');
const path    = require('path');
const cors    = require('cors');
const helmet  = require('helmet');
const morgan  = require('morgan');
const rateLimit = require('express-rate-limit');

// ── Route imports ──────────────────────────────────────────
const authRoutes         = require('./routes/auth');
const streamRoutes       = require('./routes/streams');   // unified streams
const orderRoutes        = require('./routes/orders');
const paymentRoutes      = require('./routes/payments');  // unified payments
const sellerRoutes       = require('./routes/sellers');
const buyerRoutes        = require('./routes/buyers');
const adminRoutes        = require('./routes/admin');
const walletRoutes       = require('./routes/wallet');
const uploadsRoutes      = require('./routes/uploads');
const exploreRoutes      = require('./routes/explore');
const feedRoutes         = require('./routes/feed');
const chatRoutes         = require('./routes/chat');
const featuresRoutes     = require('./routes/features');
const webhookRoutes      = require('./routes/webhook');
const reviewsRoutes      = require('./routes/reviews');
const productsRoutes     = require('./routes/products');
const cartRoutes         = require('./routes/cart');
const loyaltyRoutes      = require('./routes/loyalty');
const logisticsRoutes    = require('./routes/logistics');
const verificationRoutes = require('./routes/verification');
const { router: notificationRoutes } = require('./routes/notifications');
const { router: waRouter }           = require('./routes/whatsapp');
const notifRoutes        = require('./routes/notifications_route');

const app  = express();
const PORT = process.env.PORT || 3000;

// ── Middleware ─────────────────────────────────────────────
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc:  ["'self'"],
      scriptSrc:   ["'self'", "'unsafe-inline'"],
      scriptSrcAttr: ["'unsafe-inline'"],
      styleSrc:    ["'self'", "https:", "'unsafe-inline'"],
      imgSrc:      ["'self'", "data:", "https:", "blob:"],
      connectSrc:  ["'self'", "https:"],
      fontSrc:     ["'self'", "https:", "data:"],
      mediaSrc:    ["'self'", "blob:"],
      objectSrc:   ["'none'"],
    },
  },
  crossOriginResourcePolicy: { policy: 'cross-origin' },
}));

app.use(cors({
  origin: ['http://localhost:3000','http://localhost:5000','http://localhost:8080'],
  credentials: true,
}));
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.set('trust proxy', 1);

// Rate limits
const limiter = rateLimit({ windowMs:15*60*1000, max:100, standardHeaders:true, legacyHeaders:false, validate:{xForwardedForHeader:false} });
const authLimiter = rateLimit({ windowMs:60*60*1000, max:15, standardHeaders:true, legacyHeaders:false, validate:{xForwardedForHeader:false}, message:{error:'Too many auth attempts. Try again in an hour.'} });
app.use('/api/', limiter);
app.use('/api/auth/', authLimiter);

// ── Static files ───────────────────────────────────────────
app.use(express.static(path.join(__dirname, '../web')));
app.get('/', (req,res) => res.sendFile(path.join(__dirname,'../web/index.html')));
app.get('/live',    (req,res) => res.sendFile(path.join(__dirname,'../web/live.html')));
app.get('/product', (req,res) => res.sendFile(path.join(__dirname,'../web/product.html')));
app.get('/store',   (req,res) => res.sendFile(path.join(__dirname,'../web/store.html')));

// ── API Routes (each prefix mounted ONCE) ──────────────────
app.use('/api/auth',         authRoutes);
app.use('/api/streams',      streamRoutes);
app.use('/api/orders',       orderRoutes);
app.use('/api/payments',     paymentRoutes);
app.use('/api/sellers',      sellerRoutes);
app.use('/api/buyers',       buyerRoutes);
app.use('/api/admin',        adminRoutes);
app.use('/api/wallet',       walletRoutes);
app.use('/api/uploads',      uploadsRoutes);
app.use('/api/explore',      exploreRoutes);
app.use('/api/feed',         feedRoutes);
app.use('/api/chat',         chatRoutes);
app.use('/api/features',     featuresRoutes);
app.use('/api/reviews',      reviewsRoutes);
app.use('/api/products',     productsRoutes);
app.use('/api/cart',         cartRoutes);
app.use('/api/loyalty',      loyaltyRoutes);
app.use('/api/logistics',    logisticsRoutes);
app.use('/api/verification', verificationRoutes);
app.use('/api/notifications',notificationRoutes);
app.use('/api/notif-centre', notifRoutes);
app.use('/api/whatsapp',     waRouter);
app.use('/webhook',          webhookRoutes);

// ── Utility endpoints ──────────────────────────────────────
app.get('/health', (req,res) => res.json({status:'ok',app:'SellLive',time:new Date().toISOString()}));
app.get('/api/test', (req,res) => res.json({message:'API is working',app:'SellLive',timestamp:new Date().toISOString(),node_version:process.version}));
app.get('/api', (req,res) => res.json({app:'SellLive API',version:'1.1.0',status:'ok'}));

// ── 404 + error handlers ───────────────────────────────────
app.use('*', (req,res) => res.status(404).json({error:'Route not found'}));
app.use((err,req,res,next) => { console.error('❌',err.message); res.status(err.status||500).json({error:err.message||'Server error'}); });

if(process.env.NODE_ENV !== 'production'){
  app.listen(PORT, () => console.log(`🔴 SellLive API running on :${PORT}`));
}
module.exports = app;
