import '../../../core/failure/app_failure.dart';
import '../../../core/ids/entity_id.dart';
import '../../sftp/application/sftp_connection.dart';

class TransferTask {
  const TransferTask({
    required this.id,
    required this.direction,
    this.itemKind = TransferItemKind.file,
    required this.localPath,
    required this.remotePath,
    required this.state,
    required this.transferredBytes,
    required this.createdAt,
    this.startedAt,
    this.updatedAt,
    this.totalBytes,
    this.bytesPerSecond,
    this.eta,
    this.failure,
    this.completedAt,
  });

  final TransferTaskId id;
  final TransferDirection direction;
  final TransferItemKind itemKind;
  final String localPath;
  final String remotePath;
  final TransferState state;
  final int transferredBytes;
  final int? totalBytes;
  final double? bytesPerSecond;
  final Duration? eta;
  final AppFailure? failure;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  Map<String, Object?> toJson() {
    return {
      'id': id.value,
      'direction': direction.name,
      'itemKind': itemKind.name,
      'localPath': localPath,
      'remotePath': remotePath,
      'state': state.name,
      'transferredBytes': transferredBytes,
      'totalBytes': totalBytes,
      'bytesPerSecond': bytesPerSecond,
      'etaMilliseconds': eta?.inMilliseconds,
      'failure': failure == null ? null : _failureToJson(failure!),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'startedAt': startedAt?.toUtc().toIso8601String(),
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
      'completedAt': completedAt?.toUtc().toIso8601String(),
    };
  }

  factory TransferTask.fromJson(Map<String, Object?> json) {
    return TransferTask(
      id: TransferTaskId(json['id'] as String),
      direction: TransferDirection.values.byName(json['direction'] as String),
      itemKind: json['itemKind'] == null
          ? TransferItemKind.file
          : TransferItemKind.values.byName(json['itemKind'] as String),
      localPath: json['localPath'] as String,
      remotePath: json['remotePath'] as String,
      state: TransferState.values.byName(json['state'] as String),
      transferredBytes: json['transferredBytes'] as int,
      totalBytes: json['totalBytes'] as int?,
      bytesPerSecond: (json['bytesPerSecond'] as num?)?.toDouble(),
      eta: json['etaMilliseconds'] == null
          ? null
          : Duration(milliseconds: json['etaMilliseconds'] as int),
      failure: _failureFromJson(json['failure']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: _dateTimeFromJson(json['startedAt']),
      updatedAt: _dateTimeFromJson(json['updatedAt']),
      completedAt: _dateTimeFromJson(json['completedAt']),
    );
  }

  TransferTask copyWith({
    TransferState? state,
    int? transferredBytes,
    int? totalBytes,
    bool clearTotalBytes = false,
    double? bytesPerSecond,
    bool clearBytesPerSecond = false,
    Duration? eta,
    bool clearEta = false,
    AppFailure? failure,
    bool clearFailure = false,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TransferTask(
      id: id,
      direction: direction,
      itemKind: itemKind,
      localPath: localPath,
      remotePath: remotePath,
      state: state ?? this.state,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      totalBytes: clearTotalBytes ? null : totalBytes ?? this.totalBytes,
      bytesPerSecond: clearBytesPerSecond
          ? null
          : bytesPerSecond ?? this.bytesPerSecond,
      eta: clearEta ? null : eta ?? this.eta,
      failure: clearFailure ? null : failure ?? this.failure,
      createdAt: createdAt,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
      updatedAt: clearUpdatedAt ? null : updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    );
  }
}

class TransferQueueState {
  const TransferQueueState({required this.tasks});

  final List<TransferTask> tasks;

  TransferTask? byId(TransferTaskId id) {
    for (final task in tasks) {
      if (task.id == id) {
        return task;
      }
    }
    return null;
  }
}

Map<String, Object?> _failureToJson(AppFailure failure) {
  return {
    'code': failure.code,
    'message': failure.message,
    'diagnostic': failure.diagnostic,
    'severity': failure.severity.name,
  };
}

AppFailure? _failureFromJson(Object? value) {
  if (value == null) {
    return null;
  }
  final json = value as Map<String, Object?>;
  return AppFailure(
    code: json['code'] as String,
    message: json['message'] as String,
    diagnostic: json['diagnostic'] as String?,
    severity: FailureSeverity.values.byName(json['severity'] as String),
  );
}

DateTime? _dateTimeFromJson(Object? value) {
  return value == null ? null : DateTime.parse(value as String);
}
