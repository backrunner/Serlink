import 'dart:convert';

class WebDavTlsCertificateDetails {
  const WebDavTlsCertificateDetails({
    required this.endpoint,
    required this.fingerprint,
    required this.algorithm,
    required this.subject,
    required this.issuer,
    required this.validFrom,
    required this.validUntil,
    required this.reason,
    this.expectedFingerprint,
  });

  final Uri endpoint;
  final String fingerprint;
  final String algorithm;
  final String subject;
  final String issuer;
  final DateTime validFrom;
  final DateTime validUntil;
  final String reason;
  final String? expectedFingerprint;

  bool get requiresClockReview => reason == 'not_yet_valid';

  Map<String, Object?> toJson() {
    return {
      'endpoint': endpoint.toString(),
      'fingerprint': fingerprint,
      'algorithm': algorithm,
      'subject': subject,
      'issuer': issuer,
      'validFrom': validFrom.toUtc().toIso8601String(),
      'validUntil': validUntil.toUtc().toIso8601String(),
      'reason': reason,
      'expectedFingerprint': expectedFingerprint,
    };
  }

  factory WebDavTlsCertificateDetails.fromJson(Map<String, Object?> json) {
    return WebDavTlsCertificateDetails(
      endpoint: Uri.parse(json['endpoint'] as String),
      fingerprint: json['fingerprint'] as String,
      algorithm: json['algorithm'] as String,
      subject: json['subject'] as String,
      issuer: json['issuer'] as String,
      validFrom: DateTime.parse(json['validFrom'] as String),
      validUntil: DateTime.parse(json['validUntil'] as String),
      reason: json['reason'] as String? ?? 'trusted',
      expectedFingerprint: json['expectedFingerprint'] as String?,
    );
  }

  WebDavTlsCertificateDetails copyWith({
    String? reason,
    String? expectedFingerprint,
  }) {
    return WebDavTlsCertificateDetails(
      endpoint: endpoint,
      fingerprint: fingerprint,
      algorithm: algorithm,
      subject: subject,
      issuer: issuer,
      validFrom: validFrom,
      validUntil: validUntil,
      reason: reason ?? this.reason,
      expectedFingerprint: expectedFingerprint ?? this.expectedFingerprint,
    );
  }

  String toDiagnosticJson() => jsonEncode(toJson());

  static WebDavTlsCertificateDetails? tryParse(String? diagnostic) {
    if (diagnostic == null || diagnostic.isEmpty) {
      return null;
    }
    try {
      return WebDavTlsCertificateDetails.fromJson(
        jsonDecode(diagnostic) as Map<String, Object?>,
      );
    } on Object {
      return null;
    }
  }
}
