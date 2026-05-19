// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'TractorMate';

  @override
  String get login => 'Login';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get loginButton => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get invalidCredentials => 'Invalid username or password';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get customers => 'Customers';

  @override
  String get rentals => 'Rentals';

  @override
  String get expenses => 'Expenses';

  @override
  String get analytics => 'Analytics';

  @override
  String get reports => 'Reports';

  @override
  String get settings => 'Settings';

  @override
  String get todayEarnings => 'Today\'s Earnings';

  @override
  String get weekEarnings => 'This Week';

  @override
  String get monthEarnings => 'This Month';

  @override
  String get yearEarnings => 'This Year';

  @override
  String get totalPending => 'Total Pending';

  @override
  String get netProfit => 'Net Profit';

  @override
  String get totalExpenses => 'Total Expenses';

  @override
  String get addCustomer => 'Add Customer';

  @override
  String get editCustomer => 'Edit Customer';

  @override
  String get customerName => 'Customer Name';

  @override
  String get phone => 'Phone';

  @override
  String get notes => 'Notes';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get search => 'Search';

  @override
  String get searchCustomers => 'Search customers...';

  @override
  String get noCustomers => 'No customers yet. Tap + to add one.';

  @override
  String get totalRent => 'Total Rent';

  @override
  String get totalPaid => 'Total Paid';

  @override
  String get balance => 'Balance';

  @override
  String get rentalHistory => 'Rental History';

  @override
  String get addRental => 'Add Rental';

  @override
  String get editRental => 'Edit Rental';

  @override
  String get selectCustomer => 'Select Customer';

  @override
  String get date => 'Date';

  @override
  String get workType => 'Work Type';

  @override
  String get rentAmount => 'Rent Amount';

  @override
  String get amountPaid => 'Amount Paid';

  @override
  String get paymentStatus => 'Payment Status';

  @override
  String get remaining => 'Remaining';

  @override
  String get workTypePloughing => 'Ploughing';

  @override
  String get workTypeSowing => 'Sowing';

  @override
  String get workTypeHarvesting => 'Harvesting';

  @override
  String get workTypeLevelling => 'Levelling';

  @override
  String get workTypeOther => 'Other';

  @override
  String get statusFullyPaid => 'Fully Paid';

  @override
  String get statusPartiallyPaid => 'Partially Paid';

  @override
  String get statusUnpaid => 'Unpaid';

  @override
  String get addExpense => 'Add Expense';

  @override
  String get editExpense => 'Edit Expense';

  @override
  String get expenseCategory => 'Category';

  @override
  String get amount => 'Amount';

  @override
  String get description => 'Description';

  @override
  String get addPhoto => 'Add Photo';

  @override
  String get noExpenses => 'No expenses yet. Tap + to add one.';

  @override
  String get categoryDiesel => 'Diesel';

  @override
  String get categoryRepairs => 'Repairs';

  @override
  String get categoryMaintenance => 'Maintenance';

  @override
  String get categorySpareParts => 'Spare Parts';

  @override
  String get categoryInsurance => 'Insurance';

  @override
  String get categoryOther => 'Other';

  @override
  String get syncStatus => 'Sync Status';

  @override
  String get synced => 'Synced';

  @override
  String get syncPending => 'Sync Pending';

  @override
  String get syncError => 'Sync Error';

  @override
  String get lastSync => 'Last sync';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get kannada => 'ಕನ್ನಡ';

  @override
  String get changePassword => 'Change Password';

  @override
  String get aboutApp => 'About';

  @override
  String get version => 'Version';

  @override
  String get generateReport => 'Generate Report';

  @override
  String get shareReport => 'Share Report';

  @override
  String get exportPDF => 'Export PDF';

  @override
  String get shareViaWhatsApp => 'Share via WhatsApp';

  @override
  String get shareViaEmail => 'Share via Email';

  @override
  String get period => 'Period';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String get confirmDelete => 'Confirm Delete';

  @override
  String get deleteConfirmMessage => 'Are you sure you want to delete this?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get errorRequired => 'This field is required';

  @override
  String get errorInvalidAmount => 'Please enter a valid amount';

  @override
  String get errorNetwork => 'No internet connection';

  @override
  String get successSaved => 'Saved successfully';

  @override
  String get successDeleted => 'Deleted successfully';

  @override
  String get onboardingTitle1 => 'Track Rentals Easily';

  @override
  String get onboardingDesc1 =>
      'Record every tractor rental with customer name, work type, and payment in seconds.';

  @override
  String get onboardingTitle2 => 'Monitor All Expenses';

  @override
  String get onboardingDesc2 =>
      'Track diesel, repairs, and maintenance costs to know your true profit.';

  @override
  String get onboardingTitle3 => 'Works Offline';

  @override
  String get onboardingDesc3 =>
      'Use the app anywhere — even without internet. Data syncs automatically when you\'re back online.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get next => 'Next';

  @override
  String get skip => 'Skip';

  @override
  String get noRentals => 'No rentals yet';

  @override
  String rentalsCount(int count) {
    return '$count rentals';
  }

  @override
  String get lastRental => 'Last rental';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get connectionTest => 'Test Connection';

  @override
  String get connectionSuccess => 'Connected successfully';

  @override
  String get connectionFailed => 'Connection failed';
}
