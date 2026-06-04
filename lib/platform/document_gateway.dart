import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/security/local_file_security.dart';
import 'platform_capabilities.dart';

class PickedLocalDocument {
  const PickedLocalDocument({required this.name, required this.path});

  final String name;
  final String path;
}

class DocumentGateway {
  const DocumentGateway({required this.capabilities});

  final PlatformCapabilities capabilities;

  Future<PickedLocalDocument?> pickUploadFile({
    List<XTypeGroup> acceptedTypeGroups = const <XTypeGroup>[],
    String? confirmButtonText,
  }) async {
    final file = await openFile(
      acceptedTypeGroups: acceptedTypeGroups,
      confirmButtonText: confirmButtonText,
    );
    if (file == null) {
      return null;
    }
    final name = _displayName(file);
    if (capabilities.stableLocalFilePaths && file.path.isNotEmpty) {
      return PickedLocalDocument(name: name, path: file.path);
    }
    return PickedLocalDocument(
      name: name,
      path: await _stagePickedFile(file, name),
    );
  }

  Future<String?> pickUploadDirectory({String? confirmButtonText}) async {
    if (!capabilities.localDirectoryTransfer) {
      return null;
    }
    final directoryPath = await getDirectoryPath(
      confirmButtonText: confirmButtonText,
    );
    if (directoryPath == null || directoryPath.isEmpty) {
      return null;
    }
    return directoryPath;
  }

  Future<String?> pickFileDownloadPath({required String suggestedName}) async {
    if (capabilities.stableLocalFilePaths) {
      final location = await getSaveLocation(suggestedName: suggestedName);
      return location?.path;
    }
    final directory = await _mobileDownloadDirectory();
    return _availablePath(p.join(directory.path, _safeFileName(suggestedName)));
  }

  Future<String?> pickDirectoryDownloadPath({
    required String suggestedName,
    String? confirmButtonText,
  }) async {
    if (!capabilities.localDirectoryTransfer) {
      return null;
    }
    final parentPath = await getDirectoryPath(
      confirmButtonText: confirmButtonText,
      canCreateDirectories: true,
    );
    if (parentPath == null || parentPath.isEmpty) {
      return null;
    }
    return p.join(parentPath, suggestedName);
  }

  Future<bool> exportLocalFile(String path, {String? suggestedName}) async {
    if (!capabilities.documentExport) {
      return false;
    }
    final location = await getSaveLocation(
      suggestedName: suggestedName ?? p.basename(path),
    );
    if (location == null || location.path.isEmpty) {
      return false;
    }
    await File(path).copy(location.path);
    return true;
  }

  Future<bool> exportBytes({
    required Uint8List bytes,
    required String suggestedName,
    List<XTypeGroup> acceptedTypeGroups = const <XTypeGroup>[],
    String? mimeType,
    bool restrictPermissions = true,
  }) async {
    if (!capabilities.documentExport) {
      return false;
    }
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: acceptedTypeGroups,
    );
    if (location == null || location.path.isEmpty) {
      return false;
    }
    if (capabilities.stableLocalFilePaths) {
      final file = File(location.path);
      await file.writeAsBytes(bytes, flush: true);
      if (restrictPermissions) {
        await LocalFileSecurity.restrictExistingFile(file);
      }
      return true;
    }
    final file = XFile.fromData(bytes, mimeType: mimeType, name: suggestedName);
    await file.saveTo(location.path);
    return true;
  }

  Future<bool> exportString({
    required String contents,
    required String suggestedName,
    List<XTypeGroup> acceptedTypeGroups = const <XTypeGroup>[],
    String mimeType = 'text/plain',
    bool restrictPermissions = true,
  }) {
    return exportBytes(
      bytes: Uint8List.fromList(utf8.encode(contents)),
      suggestedName: suggestedName,
      acceptedTypeGroups: acceptedTypeGroups,
      mimeType: mimeType,
      restrictPermissions: restrictPermissions,
    );
  }

  Future<String> _stagePickedFile(XFile file, String name) async {
    final directory = await getTemporaryDirectory();
    final stagingDirectory = Directory(
      p.join(directory.path, 'serlink_uploads'),
    );
    await stagingDirectory.create(recursive: true);
    final destination = File(
      await _availablePath(p.join(stagingDirectory.path, _safeFileName(name))),
    );
    await destination.writeAsBytes(await file.readAsBytes(), flush: true);
    return destination.path;
  }

  Future<Directory> _mobileDownloadDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final downloads = Directory(p.join(documents.path, 'Downloads'));
    await downloads.create(recursive: true);
    return downloads;
  }
}

String _displayName(XFile file) {
  if (file.name.trim().isNotEmpty) {
    return _safeFileName(file.name);
  }
  if (file.path.trim().isNotEmpty) {
    return _safeFileName(p.basename(file.path));
  }
  return 'serlink-file';
}

String _safeFileName(String name) {
  final normalized = name.replaceAll(r'\', '/');
  final basename = p.basename(normalized).trim();
  if (basename.isEmpty || basename == '.' || basename == '..') {
    return 'serlink-file';
  }
  return basename;
}

Future<String> _availablePath(String desiredPath) async {
  final directory = p.dirname(desiredPath);
  final basename = p.basenameWithoutExtension(desiredPath);
  final extension = p.extension(desiredPath);
  var candidate = desiredPath;
  var index = 1;
  while (await FileSystemEntity.type(candidate) !=
      FileSystemEntityType.notFound) {
    candidate = p.join(directory, '$basename ($index)$extension');
    index += 1;
  }
  return candidate;
}
