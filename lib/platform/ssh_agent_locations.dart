import 'package:flutter/services.dart';

class SshAgentLocation {
  const SshAgentLocation({required this.path, required this.name});
  final String path;
  final String name;
}

class SshAgentLocations {
  const SshAgentLocations({this.home, this.roots = const []});
  final String? home;
  final List<SshAgentLocation> roots;
}

/// Public macOS application-group locations, including groups whose parent
/// directory cannot be enumerated by a GUI app. Tests/other platforms can
/// supply their own location source without accessing real user agents.
Future<SshAgentLocations> loadMacSshAgentLocations() async {
  try {
    final result = await const MethodChannel('serlink/platform')
        .invokeMapMethod<String, Object?>('sshAgentLocations');
    if (result == null) return const SshAgentLocations();
    return SshAgentLocations(
      home: result['home'] as String?,
      roots: [
        for (final entry in (result['roots'] as List? ?? const []))
          if (entry is Map &&
              entry['path'] is String &&
              entry['name'] is String)
            SshAgentLocation(
              path: entry['path'] as String,
              name: entry['name'] as String,
            ),
      ],
    );
  } on MissingPluginException {
    return const SshAgentLocations();
  } on PlatformException {
    return const SshAgentLocations();
  }
}
