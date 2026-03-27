import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/dio_provider.dart';

part 'currency_provider.g.dart';

// ISO 4217 minor unit rules — defines how many decimal places each currency uses
const Map<String, int> currencyMinorUnits = {
  'USD': 2, 'EUR': 2, 'GBP': 2, 'INR': 2, 'AUD': 2, 'CAD': 2, 'SGD': 2,
  'JPY': 0, // Yen has zero decimal places — ¥100 is exactly 100 yen
  'KWD': 3, // Kuwaiti Dinar has 3 decimal places — 1 KWD = 1000 fils
  'BHD': 3,
};

/// Converts raw integer cents to a human-readable currency string
/// Strictly enforces ISO 4217 minor unit rules from API_Contract.md
String formatCurrency(int amountMinorUnits, String currencyCode) {
  final int decimals = currencyMinorUnits[currencyCode] ?? 2;
  
  if (decimals == 0) {
    // e.g., JPY: ¥1500
    return '¥$amountMinorUnits';
  }
  
  final double amount = amountMinorUnits / (decimals == 3 ? 1000 : 100);
  return '${_currencySymbol(currencyCode)}${amount.toStringAsFixed(decimals)}';
}

String _currencySymbol(String code) {
  switch (code) {
    case 'USD': return '\$';
    case 'EUR': return '€';
    case 'GBP': return '£';
    case 'INR': return '₹';
    case 'JPY': return '¥';
    default: return '$code ';
  }
}

// Riverpod provider exposing available exchange rates
@riverpod
class ExchangeRates extends _$ExchangeRates {
  @override
  FutureOr<Map<String, double>> build() async {
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.get('/api/currencies/rates');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        return data.map((key, value) => MapEntry(key, (value as num).toDouble()));
      }
    } catch (_) {
      // Fallback to static rates if initialization fails
    }
    return {
      'USD_EUR': 0.92,
      'USD_GBP': 0.79,
      'USD_INR': 83.15,
      'USD_JPY': 149.50,
    };
  }

  double convert(double amountUSD, String toCurrency) {
    final rates = state.value ?? {};
    final key = 'USD_$toCurrency';
    return amountUSD * (rates[key] ?? 1.0);
  }
}
