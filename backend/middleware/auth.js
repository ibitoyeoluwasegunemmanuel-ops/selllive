// middleware/auth.js — JWT verification middleware
const jwt = require('jsonwebtoken');
const supabase = require('../config/supabase');

const authenticate = async (req, res, next) => {
  try {
    // Get token from Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided. Please log in.' });
    }

    const token = authHeader.split(' ')[1];

    // Verify JWT
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Get user from database
    const { data: user, error } = await supabase
      .from('users')
      .select('id, name, phone, role, is_verified')
      .eq('id', decoded.userId)
      .single();

    if (error || !user) {
      return res.status(401).json({ error: 'Invalid token. Please log in again.' });
    }

    // Attach user to request
    req.user = user;
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Session expired. Please log in again.' });
    }
    return res.status(401).json({ error: 'Invalid token.' });
  }
};

// Middleware: only allow sellers
const sellerOnly = (req, res, next) => {
  if (req.user.role !== 'seller') {
    return res.status(403).json({ error: 'This action is for sellers only.' });
  }
  next();
};

// Middleware: only allow admins
const adminOnly = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required.' });
  }
  next();
};

module.exports = { authenticate, sellerOnly, adminOnly };
