class Redactor {
  const Redactor._();

  static final List<RegExp> _patterns = [
    RegExp(
      r'(password|passphrase|private[_ -]?key|credential)=\S+',
      caseSensitive: false,
    ),
    RegExp(
      r'(user|username|host|hostname|path|command)=\S+',
      caseSensitive: false,
    ),
    RegExp(r'ssh-rsa\s+\S+'),
    RegExp(r'ssh-ed25519\s+\S+'),
    RegExp(
      r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----',
    ),
  ];

  static String redact(String input) {
    var output = input;
    for (final pattern in _patterns) {
      output = output.replaceAll(pattern, '[redacted]');
    }
    return output;
  }
}
