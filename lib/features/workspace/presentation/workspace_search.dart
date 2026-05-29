import '../../hosts/domain/host.dart';
import '../../snippets/domain/snippet.dart';

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
