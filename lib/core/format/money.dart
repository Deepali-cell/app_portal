import 'package:intl/intl.dart';

/// Formats an amount in the given currency (ISO code, e.g. "INR").
/// Uses the locale's symbol where known, falling back to the code.
String money(num? amount, String? currencyCode) {
  final value = amount ?? 0;
  final code = currencyCode ?? 'INR';
  final symbol = _symbols[code];
  final fmt = symbol != null
      ? NumberFormat.currency(symbol: symbol, decimalDigits: 2)
      : NumberFormat.currency(name: '$code ', decimalDigits: 2);
  return fmt.format(value);
}

const Map<String, String> _symbols = {
  'INR': '₹', // ₹
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'AED': 'AED ',
};
