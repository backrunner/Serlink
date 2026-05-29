import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_dependencies.dart';
import '../../vault/application/vault_service.dart';
import '../domain/host.dart';

final hostSummariesProvider = FutureProvider<List<HostSummary>>((ref) async {
  final vault = await ref.watch(vaultSessionControllerProvider.future);
  if (vault.vaultState != VaultState.unlocked) {
    return const [];
  }
  final hosts = await ref.watch(hostRepositoryProvider).list();
  hosts.sort((left, right) => left.displayName.compareTo(right.displayName));
  return [for (final host in hosts) host.toSummary()];
});
