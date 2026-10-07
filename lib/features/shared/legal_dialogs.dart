import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../l10n/generated/app_localizations.dart';

class LegalDialogs {
  static const String privacyPolicyUrl =
      'https://baki-khata-eosin.vercel.app/privacy';
  static const String termsOfServiceUrl =
      'https://baki-khata-eosin.vercel.app/terms';
  static const String deleteAccountUrl =
      'https://baki-khata-eosin.vercel.app/delete-account';
  static const String supportEmail = 'badgers.io.team@gmail.com';

  static Future<void> openPrivacyPolicyUrl() async {
    final uri = Uri.parse(privacyPolicyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openTermsOfServiceUrl() async {
    final uri = Uri.parse(termsOfServiceUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openDeleteAccountUrl() async {
    final uri = Uri.parse(deleteAccountUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openSupportEmail() async {
    final uri = Uri.parse('mailto:$supportEmail?subject=Baki%20Khata%20Support');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static Future<void> showPrivacyPolicyDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isBn = Localizations.localeOf(context).languageCode == 'bn';

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.privacy_tip_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n?.privacyPolicy ?? (isBn ? 'গোপনীয়তা নীতি' : 'Privacy Policy'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBn
                      ? 'সর্বশেষ আপডেট: অক্টোবর ২০২৬\n\n'
                          '১. তথ্যের গোপনীয়তা ও নীতি\n'
                          'বাকি খাতা (Baki Khata) ব্যবহারকারীদের ব্যক্তিগত এবং ব্যবসায়িক তথ্যের গোপনীয়তা রক্ষা করতে প্রতিশ্রুতিবদ্ধ। এই অ্যাপটি স্থানীয় দোকানদার ও ব্যবসায়ীদের বাকির হিসাব রাখার সুবিধার্থে তৈরি।\n\n'
                          '২. কি কি তথ্য সংরক্ষণ করা হয়?\n'
                          '• কাস্টমারদের নাম, ফোন নম্বর ও লেনদেনের বিবরণী।\n'
                          '• আপনার দোকানের নাম, যোগাযোগের ঠিকানা ও ঐচ্ছিক ডিজিটাল পেমেন্ট নম্বর (বিকাশ, নগদ, রকেট)।\n'
                          '• অ্যাকাউন্ট ব্যবহারের জন্য আপনার ইমেইল ঠিকানা।\n\n'
                          '৩. অফলাইন-ফার্স্ট এবং ক্লাউড স্টোরেজ\n'
                          'আপনার সমস্ত তথ্য আপনার ডিভাইসে অফলাইনে সুরক্ষিত থাকে (SQLite)। আপনি একাউন্টে সাইন-ইন করলে তথ্যগুলো Supabase ক্লাউডে এনক্রিপ্ট করা আকারে ব্যাকআপ হয়।\n\n'
                          '৪. বিজ্ঞাপন ও মনিটাইজেশন\n'
                          'বর্তমানে বাকি খাতা অ্যাপটিতে কোনো তৃতীয় পক্ষের বিজ্ঞাপন প্রদর্শিত হয় না। ভবিষ্যতে বিজ্ঞাপনী সেবা (যেমন: Google AdMob) বা প্রিমিয়াম লাইসেন্স যুক্ত করা হলে তা নীতিমালায় বিস্তারিত জানানো হবে। আমরা কখনো আপনার ব্যক্তিগত হিসাবের তথ্য বিক্রি করি না।\n\n'
                          '৫. WhatsApp তাগাদা\n'
                          'WhatsApp তাগাদা আপনার ডিভাইসে থাকা অফিসিয়াল WhatsApp অ্যাপের মাধ্যমে সরাসরি পাঠানো হয়। কোনো গ্রাহকের নম্বর বা বার্তা আমাদের নিজস্ব সার্ভারে সংগৃহীত হয় না।\n\n'
                          '৬. তথ্য মুছে ফেলা (Account Deletion)\n'
                          'আপনি যেকোনো সময় সেটিংস থেকে আপনার অ্যাকাউন্ট ও সমস্ত আর্থিক রেকর্ড স্থায়ীভাবে মুছে ফেলতে পারেন।'
                      : 'Last updated: October 2026\n\n'
                          '1. Privacy Commitment\n'
                          'Baki Khata is dedicated to protecting your business and financial privacy. This application is crafted for local merchants and shopkeepers to track credit ledgers with confidence.\n\n'
                          '2. Information We Collect\n'
                          '• Customer ledger profiles: names, phone numbers, and balances.\n'
                          '• Shop profile: shop name, contact address, and optional payment channels (bKash, Nagad, Rocket).\n'
                          '• Authentication data: your email address when signing in.\n\n'
                          '3. Offline-First & Cloud Security\n'
                          'All records are saved locally on your device in a secure SQLite database. When authenticated, records are synchronized with Supabase over TLS 1.3 encryption with strict Row Level Security (RLS).\n\n'
                          '4. Advertising & Monetization\n'
                          'Currently, Baki Khata does not display third-party advertisements. In future updates, should advertising (such as Google AdMob) or premium lifetime licenses be introduced, relevant data practices will be updated here and disclosed transparently under Google Play policies. We will never sell your personal financial ledger records.\n\n'
                          '5. WhatsApp Reminders\n'
                          'WhatsApp reminder messages are dispatched directly through your device\'s WhatsApp client. Customer messages are not routed through external intermediating servers.\n\n'
                          '6. Account & Data Deletion\n'
                          'You have the full right to delete your account and all associated ledger records at any time directly in the Settings menu.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF263238),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: openPrivacyPolicyUrl,
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: Text(
                    isBn ? 'ওয়েব পেজ' : 'Web Link',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isBn ? 'বুঝেছি' : 'Got it',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> showTermsOfServiceDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isBn = Localizations.localeOf(context).languageCode == 'bn';

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.gavel_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n?.termsOfService ?? (isBn ? 'ব্যবহারের শর্তাবলী' : 'Terms of Service'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              isBn
                  ? '১. সেবার শর্ত\n'
                      'বাকি খাতা একটি ডিজিটাল হিসাব খাতা ও বুককিপিং অ্যাপ্লিকেশন। এটি কোনো ব্যাংকিং বা সুদের ঋণ প্রদানকারী সেবা নয়।\n\n'
                      '২. তথ্যের নির্ভুলতা\n'
                      'গ্রাহকের বাকির পরিমাণ এবং লেনদেনের সঠিক হিসাব লিপিবদ্ধ করার দায়িত্ব ব্যবহারকারী দোকানির।\n\n'
                      '৩. ব্যাকআপ ও ডিভাইস সুরক্ষা\n'
                      'গেস্ট মোডে তথ্য শুধুমাত্র আপনার ডিভাইসেই থাকে। ডিভাইস পরিবর্তন বা অ্যাপ ডিলিট করার আগে ক্লাউড ব্যাকআপের জন্য অ্যাকাউন্টে সাইন-ইন করে নেওয়া সুপারিশ করা হয়।\n\n'
                      '৪. উপযুক্ত ব্যবহার\n'
                      'অ্যাপটি অসদুপায়ে কোনো প্রতারণামূলক কাজের জন্য ব্যবহার করা নিষিদ্ধ।'
                  : '1. Ledger Utility\n'
                      'Baki Khata is an independent digital bookkeeping utility. It does not provide banking, peer-to-peer lending, or micro-loan services.\n\n'
                      '2. Record Accuracy\n'
                      'You are solely responsible for verifying and maintaining the accuracy of recorded customer debts, credits, and ledger vouchers.\n\n'
                      '3. Backup & Security\n'
                      'In Guest Mode, records remain strictly on your local device. We recommend signing in to ensure real-time cloud backup before switching or wiping devices.\n\n'
                      '4. Acceptable Conduct\n'
                      'The application must not be utilized for unauthorized, fraudulent, or abusive transaction logging.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF263238),
              ),
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: openTermsOfServiceUrl,
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: Text(
                    isBn ? 'ওয়েব পেজ' : 'Web Link',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isBn ? 'সম্মতি দিচ্ছি' : 'I Agree',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
