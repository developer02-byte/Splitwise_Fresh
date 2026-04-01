// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'realtime_sync_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$realtimeSyncManagerHash() =>
    r'bc9e43e11177d9492cdf9756d97c3fa747d2abca';

/// Centralized Realtime Event listener.
/// Instead of injecting UI callbacks all over individual screens, this
/// background logic-only provider reads incoming socket events and intelligently
/// invalidates the localized Riverpod states, guaranteeing the UI updates
/// smoothly across the entire app.
///
/// Copied from [RealtimeSyncManager].
@ProviderFor(RealtimeSyncManager)
final realtimeSyncManagerProvider =
    NotifierProvider<RealtimeSyncManager, void>.internal(
  RealtimeSyncManager.new,
  name: r'realtimeSyncManagerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$realtimeSyncManagerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RealtimeSyncManager = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
