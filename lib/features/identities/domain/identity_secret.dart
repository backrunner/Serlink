import 'dart:convert';

class IdentitySecretMaterial {
  const IdentitySecretMaterial({
    this.password,
    this.privateKeyPem,
    this.privateKeyPassphrase,
    this.openSshCertificate,
    this.keyboardInteractiveResponses = const [],
  });

  final String? password;
  final String? privateKeyPem;
  final String? privateKeyPassphrase;
  final String? openSshCertificate;
  final List<String> keyboardInteractiveResponses;

  Map<String, Object?> toJson() {
    return {
      'password': password,
      'privateKeyPem': privateKeyPem,
      'privateKeyPassphrase': privateKeyPassphrase,
      'openSshCertificate': openSshCertificate,
      'keyboardInteractiveResponses': keyboardInteractiveResponses,
    };
  }

  factory IdentitySecretMaterial.fromJson(Map<String, Object?> json) {
    return IdentitySecretMaterial(
      password: json['password'] as String?,
      privateKeyPem: json['privateKeyPem'] as String?,
      privateKeyPassphrase: json['privateKeyPassphrase'] as String?,
      openSshCertificate: json['openSshCertificate'] as String?,
      keyboardInteractiveResponses: [
        for (final value
            in json['keyboardInteractiveResponses'] as List<Object?>)
          value as String,
      ],
    );
  }

  List<int> toBytes() => utf8.encode(jsonEncode(toJson()));

  factory IdentitySecretMaterial.fromBytes(List<int> bytes) {
    return IdentitySecretMaterial.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, Object?>,
    );
  }
}
