// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appName => 'বাকি খাতা';

  @override
  String get save => 'সংরক্ষণ করুন';

  @override
  String get cancel => 'বাতিল';

  @override
  String get delete => 'মুছে ফেলুন';

  @override
  String get edit => 'সম্পাদনা';

  @override
  String get close => 'বন্ধ করুন';

  @override
  String get retry => 'আবার চেষ্টা করুন';

  @override
  String get confirm => 'নিশ্চিত করুন';

  @override
  String get search => 'অনুসন্ধান';

  @override
  String get loading => 'লোড হচ্ছে...';

  @override
  String get error => 'সমস্যা হয়েছে';

  @override
  String get syncingLedger => 'তথ্য সিঙ্ক হচ্ছে...';

  @override
  String get navHome => 'হোম';

  @override
  String get navCustomers => 'কাস্টমার';

  @override
  String get navHistory => 'ইতিহাস';

  @override
  String get navSettings => 'সেটিংস';

  @override
  String get dashboardTitle => 'ড্যাশবোর্ড';

  @override
  String get customersTitle => 'কাস্টমার তালিকা';

  @override
  String get historyTitle => 'লেনদেনের ইতিহাস';

  @override
  String get settingsTitle => 'সেটিংস';

  @override
  String get totalDue => 'মোট বাকি';

  @override
  String get totalCustomers => 'মোট কাস্টমার';

  @override
  String get newCreditToday => 'আজকের বাকি';

  @override
  String get collectedToday => 'আজকের আদায়';

  @override
  String get totalCollectedAllTime => 'সর্বমোট আদায়';

  @override
  String get recentTransactions => 'সাম্প্রতিক লেনদেন';

  @override
  String get viewAll => 'সব দেখুন';

  @override
  String get giveCredit => 'বাকি দিন';

  @override
  String get recordPayment => 'জমা নিন';

  @override
  String get addCustomer => 'কাস্টমার যোগ';

  @override
  String get noTransactionsYet => 'এখনও কোনো লেনদেন নেই';

  @override
  String get noTransactionsDescription =>
      'সাম্প্রতিক লেনদেন দেখতে কাস্টমারকে বাকি দিন অথবা টাকা জমা রেকর্ড করুন।';

  @override
  String get searchCustomersHint => 'কাস্টমার খুঁজুন...';

  @override
  String get totalReceivable => 'মোট পাওনা:';

  @override
  String get sortBy => 'সাজান';

  @override
  String get sortName => 'নাম';

  @override
  String get sortHighestDue => 'সর্বোচ্চ বাকি';

  @override
  String get sortMostRecent => 'সাম্প্রতিক';

  @override
  String get filterAll => 'সব';

  @override
  String get filterDue => 'বাকি';

  @override
  String get filterAdvance => 'অগ্রিম';

  @override
  String get filterSettled => 'পরিশোধিত';

  @override
  String get noCustomersFound => 'কোনো কাস্টমার পাওয়া যায়নি';

  @override
  String get noCustomersMatchFilter => 'এই ফিল্টারে কোনো কাস্টমার নেই।';

  @override
  String get customerName => 'কাস্টমারের নাম';

  @override
  String get phoneNumber => 'ফোন নম্বর';

  @override
  String get address => 'ঠিকানা';

  @override
  String get addNewCustomer => 'নতুন কাস্টমার যোগ করুন';

  @override
  String get editCustomer => 'কাস্টমার সম্পাদনা করুন';

  @override
  String get editTransaction => 'লেনদেন সম্পাদনা করুন';

  @override
  String get customerDetailsTitle => 'কাস্টমার বিবরণ';

  @override
  String get call => 'কল';

  @override
  String get sms => 'এসএমএস';

  @override
  String get whatsapp => 'হোয়াটসঅ্যাপ';

  @override
  String get currentBalance => 'বর্তমান হিসাব';

  @override
  String get netDue => 'বাকি';

  @override
  String get advance => 'অগ্রিম';

  @override
  String get settled => 'পরিশোধিত';

  @override
  String get credit => 'বাকি';

  @override
  String get payment => 'জমা';

  @override
  String get noCustomerTransactions => 'কোনো লেনদেন নেই';

  @override
  String get noCustomerTransactionsHint =>
      'এই কাস্টমারের প্রথম লেনদেন যোগ করতে ওপরে বাকি দিন অথবা জমা নিন চাপুন।';

  @override
  String get deleteTransactionTitle => 'লেনদেন মুছে ফেলবেন?';

  @override
  String deleteTransactionConfirm(String type, String amount) {
    return 'আপনি কি নিশ্চিত যে এই $amount টাকার $type মুছে ফেলতে চান?';
  }

  @override
  String get deleteCustomer => 'কাস্টমার মুছে ফেলুন';

  @override
  String get deleteCustomerTitle => 'কাস্টমার মুছে ফেলবেন?';

  @override
  String deleteCustomerConfirm(String name) {
    return 'আপনি কি নিশ্চিত যে $name এবং তার সমস্ত লেনদেনের ইতিহাস মুছে ফেলতে চান? এটি আর ফিরিয়ে আনা যাবে না।';
  }

  @override
  String historyFilterAll(int count) {
    return 'সব ($count)';
  }

  @override
  String historyFilterCredit(int count) {
    return 'বাকি ($count)';
  }

  @override
  String historyFilterPayment(int count) {
    return 'জমা ($count)';
  }

  @override
  String get searchHistoryHint => 'কাস্টমার, নোট বা টাকার অঙ্ক দিয়ে খুঁজুন...';

  @override
  String get today => 'আজ';

  @override
  String get yesterday => 'গতকাল';

  @override
  String get noHistoryFound => 'কোনো লেনদেন পাওয়া যায়নি';

  @override
  String get noHistoryHint =>
      'বাকি দিলে বা জমা নিলে তা এখানে সময়ানুসারে দেখতে পাবেন।';

  @override
  String deleteHistoryConfirm(String type, String amount, String customer) {
    return 'আপনি কি নিশ্চিত যে $customer-এর $amount টাকার $type লেনদেনটি মুছে ফেলতে চান?';
  }

  @override
  String get giveCreditTitle => 'বাকি দিন';

  @override
  String get recordPaymentTitle => 'জমা নিন';

  @override
  String get selectCustomer => 'কাস্টমার নির্বাচন করুন';

  @override
  String get selectCustomerPrompt => 'একজন কাস্টমার বেছে নিন';

  @override
  String get amount => 'টাকার পরিমাণ';

  @override
  String get enterAmount => 'টাকা লিখুন';

  @override
  String get date => 'তারিখ';

  @override
  String get notesDescription => 'বিবরণ / নোট (ঐচ্ছিক)';

  @override
  String get notesHint => 'যেমন: চাল, ডাল, মেমো নং ১২৩';

  @override
  String get transactionSaved => 'লেনদেন সফলভাবে সংরক্ষণ করা হয়েছে';

  @override
  String get shopInfo => 'দোকানের তথ্য';

  @override
  String get shopName => 'দোকানের নাম';

  @override
  String get currencySymbol => 'মুদ্রার প্রতীক';

  @override
  String get shopInfoSaved => 'দোকানের তথ্য সংরক্ষিত হয়েছে';

  @override
  String get appLanguage => 'অ্যাপের ভাষা';

  @override
  String get selectLanguage => 'ভাষা নির্বাচন করুন';

  @override
  String get english => 'English';

  @override
  String get bangla => 'বাংলা';

  @override
  String get accountAndSync => 'অ্যাকাউন্ট ও ব্যাকআপ';

  @override
  String get guestMode => 'গেস্ট মোড (শুধু ডিভাইসে সংরক্ষিত)';

  @override
  String get guestWarning =>
      'আপনার তথ্য শুধু এই ফোনেই জমা আছে। নিরাপদ ব্যাকআপের জন্য সাইন ইন করুন।';

  @override
  String get signInBackup => 'সাইন ইন / ব্যাকআপ';

  @override
  String get signInOrCreateAccount => 'সাইন ইন / অ্যাকাউন্ট তৈরি করুন';

  @override
  String get signedInAs => 'লগইন করা আছে:';

  @override
  String get syncNow => 'এখনই সিঙ্ক করুন';

  @override
  String get syncing => 'সিঙ্ক হচ্ছে...';

  @override
  String get synced => 'সিঙ্ক সম্পন্ন';

  @override
  String get syncError => 'সিঙ্ক সমস্যা';

  @override
  String get offline => 'অফলাইন';

  @override
  String get syncHelpText =>
      'আপনার লেনদেন ডিভাইসে স্বয়ংক্রিয়ভাবে সংরক্ষিত থাকে এবং অনলাইনে ক্লাউডের সাথে সিঙ্ক হয়।';

  @override
  String lastSynced(String time) {
    return 'সর্বশেষ সিঙ্ক: $time';
  }

  @override
  String get neverSynced => 'কখনও সিঙ্ক হয়নি';

  @override
  String get justNow => 'এইমাত্র';

  @override
  String get customizeShopDetails =>
      'আপনার দোকানের নাম এবং মুদ্রার প্রতীক পরিবর্তন করুন।';

  @override
  String get signOut => 'লগআউট';

  @override
  String get signOutTitle => 'লগআউট করবেন?';

  @override
  String get signOutConfirm =>
      'আপনি কি নিশ্চিত যে আপনি বাকি খাতা থেকে লগআউট করতে চান? আপনার অফলাইন তথ্য নিরাপদে থাকবে।';

  @override
  String get deleteAccount => 'অ্যাকাউন্ট ডিলিট করুন';

  @override
  String get deleteAccountConfirm =>
      'আপনি কি নিশ্চিত যে অ্যাকাউন্ট ও সমস্ত তথ্য মুছে ফেলতে চান? এটি আর ফিরিয়ে আনা যাবে না।';

  @override
  String get appVersion => 'ভার্সন ১.০.০';

  @override
  String get onboardingWelcome => 'বাকি খাতায় স্বাগতম';

  @override
  String get onboardingTagline => 'সহজ ও নিরাপদ ডিজিটাল হিসাবের খাতা';

  @override
  String get setupYourShop => 'আপনার দোকান সাজিয়ে নিন';

  @override
  String get getStarted => 'শুরু করুন';

  @override
  String get signIn => 'সাইন ইন';

  @override
  String get continueAsGuest => 'গেস্ট হিসেবে এগিয়ে যান';

  @override
  String get phoneSignIn => 'ফোন নম্বর দিয়ে লগইন';

  @override
  String get googleSignIn => 'গুগল দিয়ে এগিয়ে যান';

  @override
  String get otpVerification => 'ওটিপি যাচাই';

  @override
  String get sendOtp => 'ওটিপি পাঠান';

  @override
  String get verifyOtp => 'যাচাই করে এগিয়ে যান';

  @override
  String get resendOtp => 'পুনরায় কোড পাঠান';

  @override
  String get invalidPhone => 'সঠিক ফোন নম্বর প্রদান করুন';

  @override
  String get invalidOtp => 'সঠিক ৬ ডিজিটের কোড প্রদান করুন';

  @override
  String get nameRequired => 'নাম আবশ্যক';

  @override
  String get phoneOptional => 'ফোন নম্বর (ঐচ্ছিক)';

  @override
  String get addressOptional => 'ঠিকানা (ঐচ্ছিক)';

  @override
  String get customerNamePlaceholder => 'যেমন: রহিম ট্রেডার্স, কাশেম';

  @override
  String get phonePlaceholder => 'যেমন: ০১৭১১-০০০০০০';

  @override
  String get addressPlaceholder => 'যেমন: দোকান ৪, নিউ মার্কেট, ঢাকা';

  @override
  String get setupShopTitle => 'আপনার দোকান সাজিয়ে নিন';

  @override
  String get pleaseEnterShopName => 'দোকানের নাম লিখুন';

  @override
  String get continueButton => 'এগিয়ে যান';

  @override
  String get orDivider => 'অথবা';

  @override
  String get signUp => 'সাইন আপ';

  @override
  String get createAccount => 'অ্যাকাউন্ট তৈরি করুন';

  @override
  String get loginSignUp => 'লগইন / সাইন আপ';

  @override
  String hiGreeting(String name) {
    return 'স্বাগতম $name';
  }

  @override
  String get email => 'ইমেইল';

  @override
  String get password => 'পাসওয়ার্ড';

  @override
  String get forgotPassword => 'পাসওয়ার্ড ভুলে গেছেন?';

  @override
  String get enterEmailPrompt => 'আপনার ইমেইল লিখুন';

  @override
  String get enterValidEmailPrompt => 'সঠিক ইমেইল লিখুন';

  @override
  String get enterPasswordPrompt => 'পাসওয়ার্ড লিখুন';

  @override
  String get passwordMinChars => 'পাসওয়ার্ড কমপক্ষে ৮ অক্ষরের হতে হবে';

  @override
  String get passwordHelper => 'কমপক্ষে ৮ অক্ষর';

  @override
  String get settingUpAccount => 'আপনার অ্যাকাউন্ট তৈরি হচ্ছে…';

  @override
  String get backingUpOffline => 'অফলাইন হিসাব ক্লাউডে ব্যাকআপ হচ্ছে';

  @override
  String get termsNotice =>
      'অ্যাকাউন্ট তৈরি করার মাধ্যমে আপনি আমাদের ব্যবহারের শর্তাবলী ও গোপনীয়তা নীতি মেনে নিচ্ছেন।';

  @override
  String get trackCreditTagline => 'সহজে বাকি ও জমার ডিজিটাল হিসাব রাখুন';

  @override
  String get deleteTransaction => 'লেনদেন ডিলিট করুন';
}
