import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_dependencies.dart';
import '../../vault/application/vault_service.dart';
import '../domain/host.dart';

final hostSummariesProvider = FutureProvider.autoDispose<List<HostSummary>>((
  ref,
) async {
  final vault = await ref.watch(vaultSessionControllerProvider.future);
  if (vault.vaultState != VaultState.unlocked) {
    // Stay pending while locked: resolving to an empty list here would linger
    // as stale `AsyncData([])` for one frame after unlock, flashing the empty
    // state before the real host list loads.
    return Completer<List<HostSummary>>().future;
  }
  final hosts = await ref.watch(hostRepositoryProvider).list();
  hosts.sort((left, right) => left.displayName.compareTo(right.displayName));
  return [for (final host in hosts) host.toSummary()];
});
