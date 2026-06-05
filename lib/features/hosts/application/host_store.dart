import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_dependencies.dart';
import '../../vault/application/vault_service.dart';
import '../domain/host.dart';

final hostSummariesProvider = FutureProvider.autoDispose
    .family<List<HostSummary>, int>((ref, unlockGeneration) async {
      final vault = await ref.watch(vaultSessionControllerProvider.future);
      if (vault.vaultState != VaultState.unlocked ||
          vault.unlockGeneration != unlockGeneration) {
        // Stay pending until this exact unlock generation is ready. Resolving to
        // an empty list here can leak stale `AsyncData([])` into the newly unlocked
        // list for a frame before the real records finish loading.
        return Completer<List<HostSummary>>().future;
      }
      final hosts = await ref.watch(hostRepositoryProvider).list();
      hosts.sort(
        (left, right) => left.displayName.compareTo(right.displayName),
      );
      ref.keepAlive();
      return [for (final host in hosts) host.toSummary()];
    });
