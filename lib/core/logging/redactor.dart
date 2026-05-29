import 'package:sentry_flutter/sentry_flutter.dart';

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

  static SentryEvent redactSentryEvent(SentryEvent event) {
    return event.copyWith(
      message: event.message == null
          ? null
          : SentryMessage(Redactor.redact(event.message!.formatted)),
      request: null,
      breadcrumbs: event.breadcrumbs
          ?.map(
            (breadcrumb) => breadcrumb.copyWith(
              message: breadcrumb.message == null
                  ? null
                  : Redactor.redact(breadcrumb.message!),
              data: const <String, dynamic>{'redacted': true},
            ),
          )
          .toList(),
    );
  }
}
