import '../../hosts/domain/host.dart';
import '../../snippets/domain/snippet.dart';
import '../../transfers/domain/transfer_task.dart';

List<HostSummary> filterHostSummaries(List<HostSummary> hosts, String query) {
  final normalizedQuery = normalizeWorkspaceSearchQuery(query);
  if (normalizedQuery == null) {
    return hosts;
  }
  return [
    for (final host in hosts)
      if (_hostSearchText(host).contains(normalizedQuery)) host,
  ];
}

List<CommandSnippet> filterCommandSnippets(
  List<CommandSnippet> snippets,
  String query,
) {
  final normalizedQuery = normalizeWorkspaceSearchQuery(query);
  if (normalizedQuery == null) {
    return snippets;
  }
  return [
    for (final snippet in snippets)
      if (_snippetSearchText(snippet).contains(normalizedQuery)) snippet,
  ];
}

List<TransferTask> filterTransferTasks(List<TransferTask> tasks, String query) {
  final normalizedQuery = normalizeWorkspaceSearchQuery(query);
  if (normalizedQuery == null) {
    return tasks;
  }
  return [
    for (final task in tasks)
      if (_transferSearchText(task).contains(normalizedQuery)) task,
  ];
}

String? normalizeWorkspaceSearchQuery(String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String _hostSearchText(HostSummary host) {
  return [
    host.displayName,
    host.hostname,
    host.username,
    host.port.toString(),
    ...host.tags,
  ].join(' ').toLowerCase();
}

String _snippetSearchText(CommandSnippet snippet) {
  return [
    snippet.name,
    snippet.command,
    ...snippet.tags,
  ].join(' ').toLowerCase();
}

String _transferSearchText(TransferTask task) {
  return [
    task.direction.name,
    task.itemKind.name,
    task.state.name,
    task.sourceMachineName,
    task.localPath,
    task.remotePath,
    task.failure?.message,
  ].whereType<String>().join(' ').toLowerCase();
}
