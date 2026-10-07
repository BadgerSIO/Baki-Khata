# 📱 Baki Khata (বাকি খাতা) - Privacy Policy

**Effective Date:** October 2026  
**Last Updated:** October 2026  
**Official Web Version:** [https://baki-khata-eosin.vercel.app/privacy](https://baki-khata-eosin.vercel.app/privacy)

---

## 1. Introduction & Privacy Commitment
**Baki Khata (বাকি খাতা)** is an offline-first mobile and progressive web application developed to help local merchants, small business owners, and shopkeepers record customer credit, payments, and balances. We respect your business privacy and personal confidentiality. We do not sell, rent, or monetize your ledger data with third-party advertisers or data brokers.

---

## 2. Information We Collect
We collect and process the minimum information necessary to deliver digital ledger bookkeeping:

- **Customer Profiles:** Customer names, phone numbers, and addresses that you manually enter into the ledger.
- **Transaction Ledger:** Credit (Baki) amounts, payments, running balances, notes, and dates.
- **Shop Profile:** Shop name, proprietor name, address, phone number, and optional digital payment gateway numbers (bKash, Nagad, Rocket) used for billing reminders.
- **Account & Auth Data:** If you sign in, we process your email address or Google OAuth identifier through Supabase Authentication. In Guest Mode, no personal identifying account data is collected.

---

## 3. Storage Architecture: Local-First & Cloud Synchronization
- **Local Device Storage:** All customer and transaction records are stored locally on your device in a private SQLite database (`sqflite`). The app operates with complete functionality without an active internet connection.
- **Cloud Backup (Supabase):** When authenticated, records sync to our Supabase PostgreSQL backend using industry-standard TLS 1.3 encryption and Row Level Security (RLS). Strict PostgreSQL security policies guarantee that only you can read or modify your financial records.

---

## 4. Advertising & Monetization
Currently, Baki Khata does not display third-party advertisements or integrate ad tracking SDKs. In future releases, should advertising (such as Google AdMob) or premium lifetime licenses be introduced, this policy will be updated and relevant data practices will be transparently disclosed under Google Play Developer Policies. We will never sell your customer records or financial ledgers to data brokers.

---

## 5. WhatsApp & Digital Payment Gateways (MFS)
WhatsApp reminder messages and statement breakdowns are dispatched directly through your device's installed WhatsApp application via standard deep links (`https://wa.me/` or `whatsapp://`). No customer phone numbers or messages are processed by external intermediating proxy servers.

---

## 6. Account & Data Deletion
You retain complete ownership and control over your records:
- **In-App Self-Serve Deletion:** You can permanently delete your account and all associated customer and transaction records at any time directly in **Settings &rarr; Account &rarr; Delete Account**.
- **Web-Based Deletion Portal:** If you do not have the app installed, you can submit an account deletion request at:  
  👉 [https://baki-khata-eosin.vercel.app/delete-account](https://baki-khata-eosin.vercel.app/delete-account)  
  or by emailing [badgers.io.team@gmail.com](mailto:badgers.io.team@gmail.com). All records are permanently purged.

---

## 7. Contact Us
If you have any questions or concerns regarding this Privacy Policy, please contact our team:
- **Support Email:** [badgers.io.team@gmail.com](mailto:badgers.io.team@gmail.com)
- **Official Web Application:** [https://baki-khata-eosin.vercel.app/](https://baki-khata-eosin.vercel.app/)
