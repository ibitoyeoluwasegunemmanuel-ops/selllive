# 🔴 SellLive — Nigeria's Live Commerce Platform

> "WhatsApp video calling meets Jumia" — anyone goes live, shows products, viewers buy instantly.

---

## 🏗️ Architecture

```
selllive/
├── backend/          → Node.js + Express API
├── flutter_app/      → Flutter Web (buyer + seller app)
└── database/         → Supabase SQL schema
```

---

## 🚀 Setup Guide (Step by Step)

### Step 1 — Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/selllive.git
cd selllive
```

---

### Step 2 — Set up Supabase (Database)

1. Go to [supabase.com](https://supabase.com) → Create account → New project
2. Name it `selllive`, choose a strong password, region: **West EU** (closest to Nigeria)
3. Wait for it to finish (1-2 min)
4. Click **SQL Editor** → paste the entire contents of `database/schema.sql` → click **Run**
5. Go to **Settings → API** → copy:
   - `Project URL` → save as `SUPABASE_URL`
   - `service_role` key → save as `SUPABASE_SERVICE_KEY`
   - `anon` key → save as `SUPABASE_ANON_KEY`

---

### Step 3 — Set up Flutterwave

1. Go to [dashboard.flutterwave.com](https://dashboard.flutterwave.com)
2. Create account → verify your Nigerian business
3. Go to **Settings → API Keys**
4. Copy Public Key, Secret Key, Encryption Key
5. Go to **Webhooks** → add URL: `https://your-backend.onrender.com/webhook/flutterwave`
6. Set a webhook secret and save it

---

### Step 4 — Set up Daily.co (Video)

1. Go to [daily.co](https://daily.co) → Create account (free: 1,000 mins/month)
2. Go to **Developers → API Keys** → copy your key

---

### Step 5 — Set up Termii (SMS for OTP)

1. Go to [termii.com](https://termii.com) → Create account (Nigerian SMS gateway)
2. Top up with ₦500 for testing
3. Go to **API** → copy your key
4. Request Sender ID: `SellLive`

---

### Step 6 — Run the Backend

```bash
cd backend
cp .env.example .env
# Fill in all values in .env
npm install
npm run dev
# → Server running on http://localhost:3000
```

Test it:
```bash
curl http://localhost:3000/health
# → {"status":"ok","app":"SellLive API"}
```

---

### Step 7 — Run the Flutter App

```bash
cd flutter_app
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

---

### Step 8 — Deploy Backend to Render.com

1. Push code to GitHub (see below)
2. Go to [render.com](https://render.com) → New → Web Service
3. Connect your GitHub repo
4. Set **Root Directory** to `backend`
5. Add all environment variables from `.env.example`
6. Click **Create Web Service**
7. Copy your Render URL (e.g. `https://selllive-api.onrender.com`)
8. Update `BACKEND_URL` in your Flutter app

---

### Step 9 — Deploy Flutter Web to Firebase Hosting

```bash
# Install Firebase CLI
npm install -g firebase-tools
firebase login

cd flutter_app
flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

firebase init hosting
# Public directory: build/web
# Single page app: Yes

firebase deploy
# → Your app is live at https://selllive.web.app
```

---

## 💰 Revenue Model

SellLive takes **10%** of every successful sale.

- Order: ₦10,000
- Seller receives: ₦9,000
- Platform earns: ₦1,000

Set `COMMISSION_PERCENT=10` in your `.env`

---

## 📱 App Screens

| Screen | Who | What |
|---|---|---|
| Live Feed | Buyer | See all live sellers |
| Watch Stream | Buyer | Watch + chat + BUY |
| Go Live | Seller | Start broadcasting |
| Seller Dashboard | Seller | Stats, orders, earnings |
| Orders | Buyer | Track purchases |
| Profile | Both | Account management |

---

## 🛠️ Tech Stack

| Layer | Tool |
|---|---|
| Frontend | Flutter Web |
| Backend | Node.js + Express |
| Database | Supabase (PostgreSQL) |
| Real-time chat | Supabase Realtime |
| Video | Daily.co |
| Payments | Flutterwave |
| SMS OTP | Termii |
| Backend hosting | Render.com |
| Frontend hosting | Firebase Hosting |

---

## 🔜 Roadmap (Post-MVP)

- [ ] Push notifications when followed seller goes live
- [ ] Multiple products in one stream (carousel)
- [ ] Seller analytics (charts, best-selling products)
- [ ] Buyer wishlist
- [ ] Referral system
- [ ] Escrow payment (hold until delivery confirmed)
- [ ] Android/iOS native app

---

Built with ❤️ for Nigerian traders. 🇳🇬
