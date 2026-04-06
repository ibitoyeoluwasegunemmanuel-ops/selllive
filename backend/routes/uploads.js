// routes/uploads.js — Product image upload via Supabase Storage
const express = require('express');
const router = express.Router();
const multer = require('multer');
const supabase = require('../config/supabase');
const { authenticate } = require('../middleware/auth');

// Use memory storage — upload directly to Supabase
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB max
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files allowed.'));
    }
  },
});

// ============================================================
// POST /api/uploads/product-image
// Upload a product image — returns public URL
// ============================================================
router.post('/product-image', authenticate, upload.single('image'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No image file provided.' });
  }

  const ext = req.file.originalname.split('.').pop() || 'jpg';
  const fileName = `${req.user.id}/${Date.now()}.${ext}`;
  const bucket = 'product-images';

  // Upload to Supabase Storage
  const { data, error } = await supabase.storage
    .from(bucket)
    .upload(fileName, req.file.buffer, {
      contentType: req.file.mimetype,
      upsert: false,
    });

  if (error) {
    console.error('Storage upload error:', error);
    return res.status(500).json({ error: 'Failed to upload image.' });
  }

  // Get public URL
  const { data: urlData } = supabase.storage
    .from(bucket)
    .getPublicUrl(fileName);

  res.json({
    success: true,
    url: urlData.publicUrl,
    path: fileName,
  });
});

// ============================================================
// POST /api/uploads/avatar
// Upload seller profile photo
// ============================================================
router.post('/avatar', authenticate, upload.single('image'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No image file provided.' });
  }

  const ext = req.file.originalname.split('.').pop() || 'jpg';
  const fileName = `avatars/${req.user.id}.${ext}`;
  const bucket = 'product-images'; // same bucket, different folder

  const { error } = await supabase.storage
    .from(bucket)
    .upload(fileName, req.file.buffer, {
      contentType: req.file.mimetype,
      upsert: true, // replace existing avatar
    });

  if (error) return res.status(500).json({ error: 'Failed to upload avatar.' });

  const { data: urlData } = supabase.storage
    .from(bucket)
    .getPublicUrl(fileName);

  // Update user avatar_url
  await supabase
    .from('users')
    .update({ avatar_url: urlData.publicUrl })
    .eq('id', req.user.id);

  res.json({ success: true, url: urlData.publicUrl });
});

module.exports = router;
