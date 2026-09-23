import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_dependencies.dart';
import '../../vault/application/vault_service.dart';
import 'host_repository.dart';
import 'host_group_repository.dart';
import '../domain/host.dart';

final hostGroupNamesProvider = FutureProvider.autoDispose
    .family<List<String>, int>((ref, unlockGeneration) async {
      final vault = await ref.watch(vaultSessionControllerProvider.future);
      if (vault.vaultState != VaultState.unlocked ||
          vault.unlockGeneration != unlockGeneration) {
        return Completer<List<String>>().future;
      }
      ref.watch(
        vaultRecordChangesByTypeProvider(
          EncryptedHostGroupRepository.recordType,
        ),
      );
      final groups = await ref.watch(hostGroupRepositoryProvider).list();
      ref.keepAlive();
      return groups;
    });

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
      ref.watch(
        vaultRecordChangesByTypeProvider(EncryptedHostRepository.recordType),
      );
      final hosts = await ref.watch(hostRepositoryProvider).list();
      hosts.sort((left, right) {
        final byCreatedAt = right.createdAt.compareTo(left.createdAt);
        if (byCreatedAt != 0) {
          return byCreatedAt;
        }
        final byDisplayName = left.displayName.toLowerCase().compareTo(
          right.displayName.toLowerCase(),
        );
        return byDisplayName == 0
            ? left.id.value.compareTo(right.id.value)
            : byDisplayName;
      });
      ref.keepAlive();
      return [for (final host in hosts) host.toSummary()];
    });
