import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/sftp/domain/sftp_entry.dart';

void main() {
  test('normalizes octal permissions', () {
    final permissions = SftpPermissions.tryParse('755');

    expect(permissions, isNotNull);
    expect(permissions!.octal, '0755');
    expect(permissions.normalizedOctal, '0755');
    expect(permissions.symbolic, 'rwxr-xr-x');
  });

  test('renders special permission bits symbolically', () {
    expect(SftpPermissions.fromOctal('4755').symbolic, 'rwsr-xr-x');
    expect(SftpPermissions.fromOctal('2750').symbolic, 'rwxr-s---');
    expect(SftpPermissions.fromOctal('1644').symbolic, 'rw-r--r-T');
  });

  test('parses symbolic permissions to normalized octal', () {
    expect(SftpPermissions.tryParse('rw-r--r--')!.octal, '0644');
    expect(SftpPermissions.tryParse('-rwxr-xr-x')!.octal, '0755');
    expect(SftpPermissions.tryParse('rwsr-xr-x')!.octal, '4755');
  });

  test('rejects invalid permission input', () {
    expect(SftpPermissions.tryParse('888'), isNull);
    expect(SftpPermissions.tryParse('rwxr-x'), isNull);
    expect(SftpPermissions.tryParse('rwxrwxrwq'), isNull);
  });
}
