import 'package:path/path.dart' as p;

enum TransferConflictAction { replace, skip, rename }

String nextRemoteConflictPath(String desiredPath, Set<String> existingPaths) {
  return _nextConflictPath(
    desiredPath: desiredPath,
    existingPaths: existingPaths,
    context: p.posix,
  );
}

String nextLocalConflictPath(String desiredPath, Set<String> existingPaths) {
  return _nextConflictPath(
    desiredPath: desiredPath,
    existingPaths: existingPaths,
    context: p.context,
  );
}

String _nextConflictPath({
  required String desiredPath,
  required Set<String> existingPaths,
  required p.Context context,
}) {
  if (!existingPaths.contains(desiredPath)) {
    return desiredPath;
  }

  final parent = context.dirname(desiredPath);
  final extension = context.extension(desiredPath);
  final baseName = extension.isEmpty
      ? context.basename(desiredPath)
      : context.basenameWithoutExtension(desiredPath);

  var counter = 1;
  while (true) {
    final suffix = counter == 1 ? ' copy' : ' copy $counter';
    final candidate = context.join(parent, '$baseName$suffix$extension');
    if (!existingPaths.contains(candidate)) {
      return candidate;
    }
    counter += 1;
  }
}
