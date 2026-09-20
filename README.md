# 📱 Baki Khata (বাকি খাতা) - Digital Customer Ledger & Credit Tracker

[![Flutter](https://img.shields.io/badge/Flutter-3.47.4-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.3-0175C2?logo=dart)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend%20%26%20Auth-3ECF8E?logo=supabase)](https://supabase.com)
[![PWA Ready](https://img.shields.io/badge/PWA-Installable-purple)](https://web.dev/progressive-web-apps/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A clean, modern, and production-ready **Flutter application** designed for small business owners, shopkeepers, and merchants to track customer credit (Baki), payments, and balances with ease. Built with an **offline-first** architecture, real-time cloud synchronization via **Supabase**, and multi-platform support (**Android APK** & **Web PWA deployed on Vercel**).

---

## ✨ Features

- **📊 Comprehensive Financial Dashboard**:
  - Real-time aggregate overview: **Total Net Balance**, **Receivables (Baki)**, **Payables (Advance)**, and Active Customer count.
  - Recent transactions activity feed with instant status tags.
  - Quick action FABs for lightning-fast customer & transaction entry.

- **👥 Customer Ledger Management**:
  - Detailed customer profiles with contact numbers, addresses, and balance badges (Debit / Credit / Settled).
  - Search and filter customers by debt status.
  - Complete chronological transaction history per customer.

- **💳 Transactions & Bookkeeping**:
  - Record **Baki (Debit)** and **Payment (Credit)** entries with custom timestamps and notes.
  - Automatic balance calculation and running balance audit trail.
  - WhatsApp & SMS customer reminders / statement sharing.

- **⚡ Offline-First with Supabase Sync Engine**:
  - Uses local **SQLite** (`sqflite`) for instantaneous offline operations with zero latency.
  - Automatic background synchronization (`SyncService`) with retry queue (`pending_ops`) whenever connectivity returns.
  - Resilient in-memory fallback for Flutter Web.

- **🔐 Supabase Authentication & Multi-Tenancy**:
  - **Google OAuth Login** & Email/Password with OTP verification.
  - Guest mode with automatic post-login **cloud migration & smart merge** of local guest ledgers.
  - Strict PostgreSQL **Row Level Security (RLS)** ensuring users only ever access their own financial records.

- **🌐 Progressive Web App (PWA)**:
  - Responsive layout optimized for mobile screens, tablets, and desktop browsers.
  - PWA manifest, custom app icons, and service worker for offline caching and home-screen installability.
  - Production-ready `vercel.json` for deployment on Vercel.

---

## 🏗️ Architecture & Project Structure

The project follows a clean layered architecture (Presentation, Application/State, Domain/Repository, and Data):

```
lib/
├── app.dart                    # Root navigation scaffold and tab controller
├── main.dart                   # App entrypoint and service initialization
├── core/
│   ├── current_user_service.dart # Auth session state
│   ├── supabase_client.dart      # Supabase client singleton & configuration
│   └── theme.dart                # Material 3 typography and custom emerald palette
├── data/
│   ├── local/
│   │   └── local_database.dart   # SQLite schema and in-memory Web fallback
│   ├── models/                   # Customer, Transaction, AppSettings models
│   ├── remote/                   # Supabase REST data sources
│   ├── repositories/             # Customer, Transaction, Settings repositories
│   └── sync/
│       ├── pending_op.dart       # Offline mutation queue model
│       └── sync_service.dart     # Push/pull bidirectional sync engine
└── features/
    ├── auth/                     # Sign In, Google OAuth, OTP verification, Guest merge
    ├── customers/                # Customer list, search, and detail ledgers
    ├── dashboard/                # Analytics dashboard & quick actions
    ├── history/                  # Global transaction history & filtering
    ├── onboarding/               # First-time shop setup
    ├── settings/                 # Shop profile, currency customization & backup
    └── shared/                   # Reusable balance badges, stat cards, dialogs
```

---

## 🗄️ Supabase Database Schema & Security

The backend is powered by PostgreSQL on Supabase with Row Level Security (RLS) enabled on all tables:

```sql
-- Customers Table
CREATE TABLE public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Transactions Table
CREATE TABLE public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('baki', 'payment')),
    amount NUMERIC NOT NULL CHECK (amount > 0),
    description TEXT,
    date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Settings Table
CREATE TABLE public.settings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    shop_name TEXT NOT NULL DEFAULT 'My Shop',
    currency_symbol TEXT NOT NULL DEFAULT '৳',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS Policies (Enforced on all tables)
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY customers_owner ON public.customers FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY transactions_owner ON public.transactions FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY settings_owner ON public.settings FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.24+ recommended)
- A [Supabase](https://supabase.com) account & project

### 1. Clone & Install Dependencies
```bash
git clone https://github.com/<your-username>/baki_khata_app.git
cd baki_khata_app
flutter pub get
```

### 2. Configure Environment Variables
You can pass your Supabase credentials via `--dart-define` at runtime:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<your-project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```
*(Default project credentials are also pre-configured in `lib/core/supabase_client.dart`)*.

---

## 🧪 Testing

Run the full automated test suite (58 unit and widget tests):
```bash
flutter test
```

---

## 🌐 Web & Vercel Deployment

### Build Web Release
```bash
flutter build web --release
```

### Deploy to Vercel
The project includes a pre-configured `vercel.json` with Single Page Application rewrites and cache headers.

#### Quick CLI Deploy (Fastest):
```bash
npx vercel build/web --prod
```

#### GitHub Auto-Deploy:
1. Push this repository to GitHub as a **Public repository**.
2. Connect your GitHub repository to [Vercel](https://vercel.com/new).
3. Under **Build & Development Settings**:
   - **Build Command**: `bash vercel-build.sh`
   - **Output Directory**: `build/web`
4. Click **Deploy** to receive your **Vercel Live Link**.

---

## 🤖 Android APK (Bonus)

To generate optimized split release APKs for various CPU architectures:
```bash
flutter build apk --split-per-abi
```

Generated APKs:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` *(recommended for modern Android devices)*
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

Pre-compiled APKs are also available in the `release_apk/` directory.

---

## 📄 License
This project is open-source and available under the MIT License.
