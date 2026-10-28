import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../platform/platform_capabilities.dart';

/// App Store downloads stay inside the container. The transfer UI exports
/// completed files through a native Save panel when the user chooses Export.
Future<Directory> mcpDownloadDirectory(
  PlatformCapabilities capabilities, {
  Future<Directory> Function() supportDirectory =
      getApplicationSupportDirectory,
  Future<Directory?> Function() downloadsDirectory = getDownloadsDirectory,
  Future<Directory> Function() documentsDirectory =
      getApplicationDocumentsDirectory,
}) async {
  if (capabilities.isAppStoreDistribution) {
    return Directory(p.join((await supportDirectory()).path, 'mcp-downloads'));
  }
  return await downloadsDirectory() ?? await documentsDirectory();
}
