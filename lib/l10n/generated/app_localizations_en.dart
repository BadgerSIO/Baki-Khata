// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Baki Khata';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get confirm => 'Confirm';

  @override
  String get search => 'Search';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get syncingLedger => 'Syncing your ledger...';

  @override
  String get navHome => 'Home';

  @override
  String get navCustomers => 'Customers';

  @override
  String get navHistory => 'History';

  @override
  String get navSettings => 'Settings';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get customersTitle => 'Customers';

  @override
  String get historyTitle => 'History';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get totalDue => 'Total Due';

  @override
  String get totalCustomers => 'Total Customers';

  @override
  String get newCreditToday => 'New Credit Today';

  @override
  String get collectedToday => 'Collected Today';

  @override
  String get totalCollectedAllTime => 'Total Collected All-Time';

  @override
  String get recentTransactions => 'Recent Transactions';

  @override
  String get viewAll => 'View all';

  @override
  String get giveCredit => 'Give Credit';

  @override
  String get giveCreditSubtitle => 'Gave on credit';

  @override
  String get recordPayment => 'Record Payment';

  @override
  String get recordPaymentSubtitle => 'Received cash';

  @override
  String get addCustomer => 'Add Customer';

  @override
  String get addNewCustomerAction => '+ Add Customer';

  @override
  String get relativeToday => 'Today';

  @override
  String get relativeYesterday => 'Yesterday';

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get noTransactionsYet => 'No transactions yet';

  @override
  String get noTransactionsDescription =>
      'Record customer credit or received payments to see recent activity here.';

  @override
  String get searchCustomersHint => 'Search customers...';

  @override
  String get totalReceivable => 'Total Receivable:';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortName => 'Name';

  @override
  String get sortHighestDue => 'Highest Due';

  @override
  String get sortMostRecent => 'Most Recent';

  @override
  String get filterAll => 'All';

  @override
  String get filterDue => 'Due';

  @override
  String get filterAdvance => 'Advance';

  @override
  String get filterSettled => 'Settled';

  @override
  String get noCustomersFound => 'No customers found';

  @override
  String get noCustomersMatchFilter =>
      'No customers match the current filter or search.';

  @override
  String get customerName => 'Customer Name';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get address => 'Address';

  @override
  String get addNewCustomer => 'Add New Customer';

  @override
  String get editCustomer => 'Edit Customer';

  @override
  String get editTransaction => 'Edit Transaction';

  @override
  String get customerDetailsTitle => 'Customer Details';

  @override
  String get call => 'Call';

  @override
  String get sms => 'SMS';

  @override
  String get whatsapp => 'WhatsApp';

  @override
  String get currentBalance => 'Current Balance';

  @override
  String get netDue => 'Due';

  @override
  String get advance => 'Advance';

  @override
  String get settled => 'Settled';

  @override
  String get credit => 'Credit';

  @override
  String get payment => 'Payment';

  @override
  String get noCustomerTransactions => 'No transactions yet';

  @override
  String get noCustomerTransactionsHint =>
      'Use Give Credit or Record Payment above to add the first transaction for this customer.';

  @override
  String get deleteTransactionTitle => 'Delete Transaction?';

  @override
  String deleteTransactionConfirm(String type, String amount) {
    return 'Are you sure you want to delete this $type of $amount?';
  }

  @override
  String get deleteCustomer => 'Delete Customer';

  @override
  String get deleteCustomerTitle => 'Delete Customer?';

  @override
  String deleteCustomerConfirm(String name) {
    return 'Are you sure you want to delete $name and all their transaction history? This action cannot be undone.';
  }

  @override
  String historyFilterAll(int count) {
    return 'All ($count)';
  }

  @override
  String historyFilterCredit(int count) {
    return 'Credit ($count)';
  }

  @override
  String historyFilterPayment(int count) {
    return 'Payment ($count)';
  }

  @override
  String get searchHistoryHint => 'Search by customer, note or amount...';

  @override
  String get today => 'TODAY';

  @override
  String get yesterday => 'YESTERDAY';

  @override
  String get noHistoryFound => 'No transactions found';

  @override
  String get noHistoryHint =>
      'When you give credit or record payments, they will appear here in reverse chronological order.';

  @override
  String deleteHistoryConfirm(String type, String amount, String customer) {
    return 'Are you sure you want to delete this $type of $amount for $customer?';
  }

  @override
  String get giveCreditTitle => 'Give Credit';

  @override
  String get recordPaymentTitle => 'Record Payment';

  @override
  String get selectCustomer => 'Select Customer';

  @override
  String get selectCustomerPrompt => 'Choose a customer';

  @override
  String get amount => 'Amount';

  @override
  String get enterAmount => 'Enter amount';

  @override
  String get date => 'Date';

  @override
  String get notesDescription => 'Notes / Description (Optional)';

  @override
  String get notesHint => 'e.g. Groceries, Invoice #123';

  @override
  String get transactionSaved => 'Transaction saved successfully';

  @override
  String get shopInfo => 'Shop Information';

  @override
  String get shopName => 'Shop Name';

  @override
  String get currencySymbol => 'Currency Symbol';

  @override
  String get shopInfoSaved => 'Shop information saved';

  @override
  String get appLanguage => 'App Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get bangla => 'বাংলা';

  @override
  String get accountAndSync => 'Account & Sync';

  @override
  String get guestMode => 'Guest Mode (Local Only)';

  @override
  String get guestWarning =>
      'Sign in to back up and sync your data to the cloud';

  @override
  String get signInBackup => 'Sign In / Back Up';

  @override
  String get signInOrCreateAccount => 'Sign In / Create Account';

  @override
  String get signedInAs => 'Signed in as';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get syncing => 'Syncing...';

  @override
  String get synced => 'Synced';

  @override
  String get syncError => 'Sync Error';

  @override
  String get offline => 'Offline';

  @override
  String get syncHelpText =>
      'Your records are automatically saved on this device and synced to your cloud account when online.';

  @override
  String lastSynced(String time) {
    return 'Last synced: $time';
  }

  @override
  String get neverSynced => 'Never synced';

  @override
  String get justNow => 'Just now';

  @override
  String get customizeShopDetails =>
      'Customize your shop name and currency symbol.';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutTitle => 'Sign Out?';

  @override
  String get signOutConfirm =>
      'Are you sure you want to sign out of Baki Khata? Any pending offline data remains safely stored on this device.';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirm =>
      'Are you sure you want to permanently delete your account and all associated data? This action cannot be undone.';

  @override
  String get appVersion => 'Version 1.0.0';

  @override
  String get onboardingWelcome => 'Welcome to Baki Khata';

  @override
  String get onboardingTagline => 'Your simple, smart digital credit ledger';

  @override
  String get setupYourShop => 'Set Up Your Shop';

  @override
  String get getStarted => 'Get Started';

  @override
  String get signIn => 'Sign In';

  @override
  String get continueAsGuest => 'Continue as Guest';

  @override
  String get phoneSignIn => 'Phone Sign In';

  @override
  String get googleSignIn => 'Continue with Google';

  @override
  String get otpVerification => 'OTP Verification';

  @override
  String get sendOtp => 'Send OTP';

  @override
  String get verifyOtp => 'Verify & Continue';

  @override
  String get resendOtp => 'Resend Code';

  @override
  String get invalidPhone => 'Please enter a valid phone number';

  @override
  String get invalidOtp => 'Please enter a valid 6-digit code';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get phoneOptional => 'Phone Number (optional)';

  @override
  String get addressOptional => 'Address (optional)';

  @override
  String get customerNamePlaceholder => 'e.g. Rahim Traders, Kashem';

  @override
  String get phonePlaceholder => 'e.g. 01711-000000';

  @override
  String get addressPlaceholder => 'e.g. Shop 4, New Market, Dhaka';

  @override
  String get setupShopTitle => 'Let\'s set up your shop';

  @override
  String get pleaseEnterShopName => 'Please enter your shop name';

  @override
  String get continueButton => 'Continue';

  @override
  String get orDivider => 'OR';

  @override
  String get signUp => 'Sign Up';

  @override
  String get createAccount => 'Create Account';

  @override
  String get loginSignUp => 'Login / Sign Up';

  @override
  String hiGreeting(String name) {
    return 'Hi $name';
  }

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get enterEmailPrompt => 'Please enter your email';

  @override
  String get enterValidEmailPrompt => 'Please enter a valid email address';

  @override
  String get enterPasswordPrompt => 'Please enter a password';

  @override
  String get passwordMinChars => 'Password must be at least 8 characters';

  @override
  String get passwordHelper => 'Minimum 8 characters';

  @override
  String get settingUpAccount => 'Setting up your account…';

  @override
  String get backingUpOffline => 'Backing up your offline ledger to the cloud';

  @override
  String get termsNotice =>
      'By creating an account, you agree to our Terms of Service and Privacy Policy.';

  @override
  String get deleteTransaction => 'Delete Transaction';

  @override
  String get digitalVoucher => 'Digital Voucher / Cash Memo';

  @override
  String get voucherNumber => 'Memo No.';

  @override
  String get sendOnWhatsApp => 'Send on WhatsApp';

  @override
  String get sendImage => 'Send Image';

  @override
  String get sendText => 'Send Text';

  @override
  String get previousDue => 'Previous Due';

  @override
  String get currentAmount => 'Current Amount';

  @override
  String get newTotalDue => 'Total Net Due';

  @override
  String get addItem => 'Add Item';

  @override
  String get itemName => 'Item Name';

  @override
  String get quantity => 'Quantity';

  @override
  String get shopPhone => 'Shop Phone';

  @override
  String get shopAddress => 'Shop Address';

  @override
  String get autoShowReceipt => 'Auto-show Voucher';

  @override
  String get viewVoucher => 'View Voucher';

  @override
  String get saveImage => 'Save Image';

  @override
  String get trackCreditTagline => 'Track customer credit, the simple way';
}
