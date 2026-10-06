import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Baki Khata'**
  String get appName;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @syncingLedger.
  ///
  /// In en, this message translates to:
  /// **'Syncing your ledger...'**
  String get syncingLedger;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get navCustomers;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @customersTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customersTitle;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @totalDue.
  ///
  /// In en, this message translates to:
  /// **'Total Due'**
  String get totalDue;

  /// No description provided for @totalCustomers.
  ///
  /// In en, this message translates to:
  /// **'Total Customers'**
  String get totalCustomers;

  /// No description provided for @newCreditToday.
  ///
  /// In en, this message translates to:
  /// **'New Credit Today'**
  String get newCreditToday;

  /// No description provided for @collectedToday.
  ///
  /// In en, this message translates to:
  /// **'Collected Today'**
  String get collectedToday;

  /// No description provided for @totalCollectedAllTime.
  ///
  /// In en, this message translates to:
  /// **'Total Collected All-Time'**
  String get totalCollectedAllTime;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @giveCredit.
  ///
  /// In en, this message translates to:
  /// **'Give Credit'**
  String get giveCredit;

  /// No description provided for @giveCreditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Gave on credit'**
  String get giveCreditSubtitle;

  /// No description provided for @recordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get recordPayment;

  /// No description provided for @recordPaymentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Received cash'**
  String get recordPaymentSubtitle;

  /// No description provided for @addCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add Customer'**
  String get addCustomer;

  /// No description provided for @addNewCustomerAction.
  ///
  /// In en, this message translates to:
  /// **'+ Add Customer'**
  String get addNewCustomerAction;

  /// No description provided for @relativeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get relativeToday;

  /// No description provided for @relativeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get relativeYesterday;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactionsYet;

  /// No description provided for @noTransactionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Record customer credit or received payments to see recent activity here.'**
  String get noTransactionsDescription;

  /// No description provided for @searchCustomersHint.
  ///
  /// In en, this message translates to:
  /// **'Search customers...'**
  String get searchCustomersHint;

  /// No description provided for @totalReceivable.
  ///
  /// In en, this message translates to:
  /// **'Total Receivable:'**
  String get totalReceivable;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// No description provided for @sortHighestDue.
  ///
  /// In en, this message translates to:
  /// **'Highest Due'**
  String get sortHighestDue;

  /// No description provided for @sortMostRecent.
  ///
  /// In en, this message translates to:
  /// **'Most Recent'**
  String get sortMostRecent;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get filterDue;

  /// No description provided for @filterAdvance.
  ///
  /// In en, this message translates to:
  /// **'Advance'**
  String get filterAdvance;

  /// No description provided for @filterSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get filterSettled;

  /// No description provided for @noCustomersFound.
  ///
  /// In en, this message translates to:
  /// **'No customers found'**
  String get noCustomersFound;

  /// No description provided for @noCustomersMatchFilter.
  ///
  /// In en, this message translates to:
  /// **'No customers match the current filter or search.'**
  String get noCustomersMatchFilter;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer Name'**
  String get customerName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @addNewCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add New Customer'**
  String get addNewCustomer;

  /// No description provided for @editCustomer.
  ///
  /// In en, this message translates to:
  /// **'Edit Customer'**
  String get editCustomer;

  /// No description provided for @editTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit Transaction'**
  String get editTransaction;

  /// No description provided for @customerDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer Details'**
  String get customerDetailsTitle;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @sms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get sms;

  /// No description provided for @whatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get whatsapp;

  /// No description provided for @currentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current Balance'**
  String get currentBalance;

  /// No description provided for @netDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get netDue;

  /// No description provided for @advance.
  ///
  /// In en, this message translates to:
  /// **'Advance'**
  String get advance;

  /// No description provided for @settled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get settled;

  /// No description provided for @credit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get credit;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @noCustomerTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noCustomerTransactions;

  /// No description provided for @noCustomerTransactionsHint.
  ///
  /// In en, this message translates to:
  /// **'Use Give Credit or Record Payment above to add the first transaction for this customer.'**
  String get noCustomerTransactionsHint;

  /// No description provided for @deleteTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Transaction?'**
  String get deleteTransactionTitle;

  /// No description provided for @deleteTransactionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this {type} of {amount}?'**
  String deleteTransactionConfirm(String type, String amount);

  /// No description provided for @deleteCustomer.
  ///
  /// In en, this message translates to:
  /// **'Delete Customer'**
  String get deleteCustomer;

  /// No description provided for @deleteCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Customer?'**
  String get deleteCustomerTitle;

  /// No description provided for @deleteCustomerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name} and all their transaction history? This action cannot be undone.'**
  String deleteCustomerConfirm(String name);

  /// No description provided for @historyFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String historyFilterAll(int count);

  /// No description provided for @historyFilterCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit ({count})'**
  String historyFilterCredit(int count);

  /// No description provided for @historyFilterPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment ({count})'**
  String historyFilterPayment(int count);

  /// No description provided for @searchHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Search by customer, note or amount...'**
  String get searchHistoryHint;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'YESTERDAY'**
  String get yesterday;

  /// No description provided for @noHistoryFound.
  ///
  /// In en, this message translates to:
  /// **'No transactions found'**
  String get noHistoryFound;

  /// No description provided for @noHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'When you give credit or record payments, they will appear here in reverse chronological order.'**
  String get noHistoryHint;

  /// No description provided for @deleteHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this {type} of {amount} for {customer}?'**
  String deleteHistoryConfirm(String type, String amount, String customer);

  /// No description provided for @giveCreditTitle.
  ///
  /// In en, this message translates to:
  /// **'Give Credit'**
  String get giveCreditTitle;

  /// No description provided for @recordPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get recordPaymentTitle;

  /// No description provided for @selectCustomer.
  ///
  /// In en, this message translates to:
  /// **'Select Customer'**
  String get selectCustomer;

  /// No description provided for @selectCustomerPrompt.
  ///
  /// In en, this message translates to:
  /// **'Choose a customer'**
  String get selectCustomerPrompt;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @enterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get enterAmount;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @notesDescription.
  ///
  /// In en, this message translates to:
  /// **'Notes / Description (Optional)'**
  String get notesDescription;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Groceries, Invoice #123'**
  String get notesHint;

  /// No description provided for @transactionSaved.
  ///
  /// In en, this message translates to:
  /// **'Transaction saved successfully'**
  String get transactionSaved;

  /// No description provided for @shopInfo.
  ///
  /// In en, this message translates to:
  /// **'Shop Information'**
  String get shopInfo;

  /// No description provided for @shopName.
  ///
  /// In en, this message translates to:
  /// **'Shop Name'**
  String get shopName;

  /// No description provided for @currencySymbol.
  ///
  /// In en, this message translates to:
  /// **'Currency Symbol'**
  String get currencySymbol;

  /// No description provided for @shopInfoSaved.
  ///
  /// In en, this message translates to:
  /// **'Shop information saved'**
  String get shopInfoSaved;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @bangla.
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get bangla;

  /// No description provided for @accountAndSync.
  ///
  /// In en, this message translates to:
  /// **'Account & Sync'**
  String get accountAndSync;

  /// No description provided for @guestMode.
  ///
  /// In en, this message translates to:
  /// **'Guest Mode (Local Only)'**
  String get guestMode;

  /// No description provided for @guestWarning.
  ///
  /// In en, this message translates to:
  /// **'Sign in to back up and sync your data to the cloud'**
  String get guestWarning;

  /// No description provided for @signInBackup.
  ///
  /// In en, this message translates to:
  /// **'Sign In / Back Up'**
  String get signInBackup;

  /// No description provided for @signInOrCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign In / Create Account'**
  String get signInOrCreateAccount;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get signedInAs;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNow;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// No description provided for @syncError.
  ///
  /// In en, this message translates to:
  /// **'Sync Error'**
  String get syncError;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @syncHelpText.
  ///
  /// In en, this message translates to:
  /// **'Your records are automatically saved on this device and synced to your cloud account when online.'**
  String get syncHelpText;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {time}'**
  String lastSynced(String time);

  /// No description provided for @neverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get neverSynced;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @customizeShopDetails.
  ///
  /// In en, this message translates to:
  /// **'Customize your shop name and currency symbol.'**
  String get customizeShopDetails;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out?'**
  String get signOutTitle;

  /// No description provided for @signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out of Baki Khata? Any pending offline data remains safely stored on this device.'**
  String get signOutConfirm;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete your account and all associated data? This action cannot be undone.'**
  String get deleteAccountConfirm;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0'**
  String get appVersion;

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Baki Khata'**
  String get onboardingWelcome;

  /// No description provided for @onboardingTagline.
  ///
  /// In en, this message translates to:
  /// **'Your simple, smart digital credit ledger'**
  String get onboardingTagline;

  /// No description provided for @setupYourShop.
  ///
  /// In en, this message translates to:
  /// **'Set Up Your Shop'**
  String get setupYourShop;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueAsGuest;

  /// No description provided for @phoneSignIn.
  ///
  /// In en, this message translates to:
  /// **'Phone Sign In'**
  String get phoneSignIn;

  /// No description provided for @googleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get googleSignIn;

  /// No description provided for @otpVerification.
  ///
  /// In en, this message translates to:
  /// **'OTP Verification'**
  String get otpVerification;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOtp;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify & Continue'**
  String get verifyOtp;

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendOtp;

  /// No description provided for @invalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get invalidPhone;

  /// No description provided for @invalidOtp.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 6-digit code'**
  String get invalidOtp;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @phoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone Number (optional)'**
  String get phoneOptional;

  /// No description provided for @addressOptional.
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get addressOptional;

  /// No description provided for @customerNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Rahim Traders, Kashem'**
  String get customerNamePlaceholder;

  /// No description provided for @phonePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. 01711-000000'**
  String get phonePlaceholder;

  /// No description provided for @addressPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Shop 4, New Market, Dhaka'**
  String get addressPlaceholder;

  /// No description provided for @setupShopTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s set up your shop'**
  String get setupShopTitle;

  /// No description provided for @pleaseEnterShopName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your shop name'**
  String get pleaseEnterShopName;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orDivider;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @loginSignUp.
  ///
  /// In en, this message translates to:
  /// **'Login / Sign Up'**
  String get loginSignUp;

  /// No description provided for @hiGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}'**
  String hiGreeting(String name);

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @enterEmailPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get enterEmailPrompt;

  /// No description provided for @enterValidEmailPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get enterValidEmailPrompt;

  /// No description provided for @enterPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get enterPasswordPrompt;

  /// No description provided for @passwordMinChars.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMinChars;

  /// No description provided for @passwordHelper.
  ///
  /// In en, this message translates to:
  /// **'Minimum 8 characters'**
  String get passwordHelper;

  /// No description provided for @settingUpAccount.
  ///
  /// In en, this message translates to:
  /// **'Setting up your account…'**
  String get settingUpAccount;

  /// No description provided for @backingUpOffline.
  ///
  /// In en, this message translates to:
  /// **'Backing up your offline ledger to the cloud'**
  String get backingUpOffline;

  /// No description provided for @termsNotice.
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you agree to our Terms of Service and Privacy Policy.'**
  String get termsNotice;

  /// No description provided for @deleteTransaction.
  ///
  /// In en, this message translates to:
  /// **'Delete Transaction'**
  String get deleteTransaction;

  /// No description provided for @digitalVoucher.
  ///
  /// In en, this message translates to:
  /// **'Digital Voucher / Cash Memo'**
  String get digitalVoucher;

  /// No description provided for @voucherNumber.
  ///
  /// In en, this message translates to:
  /// **'Memo No.'**
  String get voucherNumber;

  /// No description provided for @sendOnWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Send on WhatsApp'**
  String get sendOnWhatsApp;

  /// No description provided for @sendImage.
  ///
  /// In en, this message translates to:
  /// **'Send Image'**
  String get sendImage;

  /// No description provided for @sendText.
  ///
  /// In en, this message translates to:
  /// **'Send Text'**
  String get sendText;

  /// No description provided for @previousDue.
  ///
  /// In en, this message translates to:
  /// **'Previous Due'**
  String get previousDue;

  /// No description provided for @currentAmount.
  ///
  /// In en, this message translates to:
  /// **'Current Amount'**
  String get currentAmount;

  /// No description provided for @newTotalDue.
  ///
  /// In en, this message translates to:
  /// **'Total Net Due'**
  String get newTotalDue;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Item Name'**
  String get itemName;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @shopPhone.
  ///
  /// In en, this message translates to:
  /// **'Shop Phone'**
  String get shopPhone;

  /// No description provided for @shopAddress.
  ///
  /// In en, this message translates to:
  /// **'Shop Address'**
  String get shopAddress;

  /// No description provided for @autoShowReceipt.
  ///
  /// In en, this message translates to:
  /// **'Auto-show Voucher'**
  String get autoShowReceipt;

  /// No description provided for @viewVoucher.
  ///
  /// In en, this message translates to:
  /// **'View Voucher'**
  String get viewVoucher;

  /// No description provided for @saveImage.
  ///
  /// In en, this message translates to:
  /// **'Save Image'**
  String get saveImage;

  /// No description provided for @trackCreditTagline.
  ///
  /// In en, this message translates to:
  /// **'Track customer credit, the simple way'**
  String get trackCreditTagline;

  /// No description provided for @sendDueReminder.
  ///
  /// In en, this message translates to:
  /// **'Send Due Reminder'**
  String get sendDueReminder;

  /// No description provided for @sendStatement.
  ///
  /// In en, this message translates to:
  /// **'Send Statement'**
  String get sendStatement;

  /// No description provided for @whatsappReminder.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Reminder'**
  String get whatsappReminder;

  /// No description provided for @whatsappStatement.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Statement'**
  String get whatsappStatement;

  /// No description provided for @politeTone.
  ///
  /// In en, this message translates to:
  /// **'Polite'**
  String get politeTone;

  /// No description provided for @urgentTone.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get urgentTone;

  /// No description provided for @statementTone.
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get statementTone;

  /// No description provided for @addPhoneToRemind.
  ///
  /// In en, this message translates to:
  /// **'Add phone number to send reminder'**
  String get addPhoneToRemind;

  /// No description provided for @addPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'+ Add Phone'**
  String get addPhoneNumber;

  /// No description provided for @lastReminded.
  ///
  /// In en, this message translates to:
  /// **'Last reminded: {time}'**
  String lastReminded(String time);

  /// No description provided for @reminderMessageCopied.
  ///
  /// In en, this message translates to:
  /// **'Reminder message copied to clipboard'**
  String get reminderMessageCopied;

  /// No description provided for @openWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Open WhatsApp'**
  String get openWhatsApp;

  /// No description provided for @shareViaOther.
  ///
  /// In en, this message translates to:
  /// **'Share via Other'**
  String get shareViaOther;

  /// No description provided for @copyMessage.
  ///
  /// In en, this message translates to:
  /// **'Copy Message'**
  String get copyMessage;

  /// No description provided for @whatsappNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp is not installed'**
  String get whatsappNotInstalled;

  /// No description provided for @couldNotLaunchWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Could not open WhatsApp'**
  String get couldNotLaunchWhatsApp;

  /// No description provided for @paymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Digital Payment Methods'**
  String get paymentMethods;

  /// No description provided for @paymentMethodsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure bKash, Nagad & Rocket for reminders'**
  String get paymentMethodsSubtitle;

  /// No description provided for @bkash.
  ///
  /// In en, this message translates to:
  /// **'bKash'**
  String get bkash;

  /// No description provided for @nagad.
  ///
  /// In en, this message translates to:
  /// **'Nagad'**
  String get nagad;

  /// No description provided for @rocket.
  ///
  /// In en, this message translates to:
  /// **'Rocket'**
  String get rocket;

  /// No description provided for @accountType.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get accountType;

  /// No description provided for @personal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get personal;

  /// No description provided for @merchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get merchant;

  /// No description provided for @sendMoney.
  ///
  /// In en, this message translates to:
  /// **'Send Money'**
  String get sendMoney;

  /// No description provided for @makePayment.
  ///
  /// In en, this message translates to:
  /// **'Make Payment'**
  String get makePayment;

  /// No description provided for @trxIdConfirmationPrompt.
  ///
  /// In en, this message translates to:
  /// **'After payment, please reply with TrxID or screenshot to confirm.'**
  String get trxIdConfirmationPrompt;

  /// No description provided for @addPaymentMethodsTip.
  ///
  /// In en, this message translates to:
  /// **'Add bKash or Nagad in Settings to include payment info in reminders'**
  String get addPaymentMethodsTip;

  /// No description provided for @configureInSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get configureInSettings;

  /// No description provided for @payAtShopPrompt.
  ///
  /// In en, this message translates to:
  /// **'Kindly request to settle the balance at the shop.'**
  String get payAtShopPrompt;

  /// No description provided for @contactOrShopPrompt.
  ///
  /// In en, this message translates to:
  /// **'Pay at shop or contact:'**
  String get contactOrShopPrompt;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
