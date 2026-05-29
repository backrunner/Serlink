import '../../../core/ids/entity_id.dart';

class CommandSnippet {
  const CommandSnippet({
    required this.id,
    required this.name,
    required this.command,
    required this.tags,
    required this.confirmBeforeRun,
    required this.createdAt,
    required this.updatedAt,
  });

  final SnippetId id;
  final String name;
  final String command;
  final Set<String> tags;
  final bool confirmBeforeRun;
  final DateTime createdAt;
  final DateTime updatedAt;

  CommandSnippet copyWith({
    String? name,
    String? command,
    Set<String>? tags,
    bool? confirmBeforeRun,
    DateTime? updatedAt,
  }) {
    return CommandSnippet(
      id: id,
      name: name ?? this.name,
      command: command ?? this.command,
      tags: tags ?? this.tags,
      confirmBeforeRun: confirmBeforeRun ?? this.confirmBeforeRun,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id.value,
      'name': name,
      'command': command,
      'tags': tags.toList()..sort(),
      'confirmBeforeRun': confirmBeforeRun,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory CommandSnippet.fromJson(Map<String, Object?> json) {
    return CommandSnippet(
      id: SnippetId(json['id'] as String),
      name: json['name'] as String,
      command: json['command'] as String,
      tags: {for (final tag in json['tags'] as List<Object?>) tag as String},
      confirmBeforeRun: json['confirmBeforeRun'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
