# ============================================================
# FIREBASE SETUP FOR SELLLIVE
# Follow these steps to enable push notifications
# ============================================================

## Step 1 — Create Firebase Project

1. Go to https://console.firebase.google.com
2. Click "Add project" → name it "selllive"
3. Disable Google Analytics (not needed now)
4. Click "Create project"

## Step 2 — Add Android App

1. Click the Android icon (🤖)
2. Android package name: `ng.selllive.app`
3. App nickname: `SellLive Android`
4. Click "Register app"
5. Download `google-services.json`
6. Place it at: `flutter_app/android/app/google-services.json`
7. Click Next → Next → Continue to console

## Step 3 — Add iOS App

1. Click the iOS icon (🍎)
2. iOS bundle ID: `ng.selllive.app`
3. App nickname: `SellLive iOS`
4. Click "Register app"
5. Download `GoogleService-Info.plist`
6. Place it at: `flutter_app/ios/Runner/GoogleService-Info.plist`
7. Click Next → Next → Continue to console

## Step 4 — Enable Cloud Messaging

1. In Firebase console → Project Settings → Cloud Messaging
2. Note your Server Key (for sending notifications from backend)
3. Add to Vercel env vars as: `FIREBASE_SERVER_KEY`

## Step 5 — Add to GitHub Secrets (for APK build)

After downloading both files, add to GitHub Actions secrets:
- `GOOGLE_SERVICES_JSON` = contents of google-services.json (base64 encoded)
- `GOOGLE_SERVICES_PLIST` = contents of GoogleService-Info.plist (base64 encoded)

Encode with:
  base64 -w 0 google-services.json
  base64 -w 0 GoogleService-Info.plist

## Step 6 — Supabase Storage Bucket

Run this SQL in Supabase SQL Editor:
```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true);

CREATE POLICY "Public read" ON storage.objects
FOR SELECT USING (bucket_id = 'product-images');

CREATE POLICY "Seller upload" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'product-images' AND
  auth.role() = 'authenticated'
);
```

## Step 7 — Vercel Environment Variables to Add

Go to: vercel.com → selllive → Settings → Environment Variables

Add these:
| Variable | Value |
|---|---|
| SUPABASE_SERVICE_KEY | (from Supabase → Settings → API → service_role) |
| FIREBASE_SERVER_KEY | (from Firebase → Project Settings → Cloud Messaging) |

That's it! Push notifications + image uploads will work automatically.
