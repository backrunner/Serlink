part of '../workspace_screen.dart';

String _fileName(String path) {
  final parts = path
      .split(RegExp(r'[\\/]'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return path;
  }
  return parts.last;
}

String _parentPath(String path) {
  final normalized = _joinRemotePath(path);
  if (normalized == '/') {
    return '/';
  }
  final index = normalized.lastIndexOf('/');
  if (index <= 0) {
    return '/';
  }
  return normalized.substring(0, index);
}

String _remoteChildPath(String parent, String childName) {
  final normalizedParent = _joinRemotePath(parent);
  final cleanChild = childName
      .split('/')
      .where((segment) => segment.isNotEmpty && segment != '.')
      .join('/');
  if (cleanChild.isEmpty) {
    return normalizedParent;
  }
  if (normalizedParent == '/') {
    return '/$cleanChild';
  }
  return '$normalizedParent/$cleanChild';
}

String _resolveMoveTarget(String target, String entryName) {
  if (target.endsWith('/')) {
    return _remoteChildPath(target, entryName);
  }
  return _joinRemotePath(target);
}

bool _sameRemotePath(String left, String right) {
  return _joinRemotePath(left) == _joinRemotePath(right);
}

bool _isOctalPermissions(String value) {
  return RegExp(r'^[0-7]{3,4}$').hasMatch(value);
}

String _joinRemotePath(String path) {
  final segments = <String>[];
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (segments.isNotEmpty) {
        segments.removeLast();
      }
      continue;
    }
    segments.add(segment);
  }
  return '/${segments.join('/')}';
}

Future<String?> _showTextInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  String initialValue = '',
}) {
  return showSerlinkDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _TextInputDialog(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      initialValue: initialValue,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.initialValue,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String initialValue;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthCompact),
      title: Text(widget.title),
      content: SerlinkTextField(
        key: ValueKey('text-input-${widget.label}'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        SerlinkFilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
