import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _inrDecimal = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

String formatRupees(double amount, {bool showDecimals = false}) {
  return showDecimals ? _inrDecimal.format(amount) : _inr.format(amount);
}

String formatDate(DateTime dt) => DateFormat('dd MMM yyyy').format(dt);
String formatDateShort(DateTime dt) => DateFormat('dd/MM/yy').format(dt);
