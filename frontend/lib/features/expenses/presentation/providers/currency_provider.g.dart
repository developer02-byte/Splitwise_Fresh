// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$exchangeRatesHash() => r'e83c23041a4a076ab104c3f4537c7776ab7c0519';

/// See also [ExchangeRates].
@ProviderFor(ExchangeRates)
final exchangeRatesProvider = AutoDisposeAsyncNotifierProvider<ExchangeRates,
    Map<String, double>>.internal(
  ExchangeRates.new,
  name: r'exchangeRatesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$exchangeRatesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ExchangeRates = AutoDisposeAsyncNotifier<Map<String, double>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
