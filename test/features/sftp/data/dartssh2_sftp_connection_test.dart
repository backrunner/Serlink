import 'package:dartssh2/dartssh2.dart' as ssh;
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/sftp/data/dartssh2_sftp_connection.dart';
import 'package:serlink/features/sftp/domain/sftp_entry.dart';

void main() {
  test('maps dartssh2 directory entries to Serlink SFTP entries', () {
    final entry = DartSsh2SftpConnection.mapName(
      path: '/var/www',
      name: ssh.SftpName(
        filename: '.releases',
        longname: '',
        attr: ssh.SftpFileAttrs(
          size: 4096,
          userID: 501,
          groupID: 20,
          mode: ssh.SftpFileMode.value(int.parse('40755', radix: 8)),
          modifyTime: 1780000000,
        ),
      ),
    );

    expect(entry.name, '.releases');
    expect(entry.path, '/var/www/.releases');
    expect(entry.type, SftpEntryType.directory);
    expect(entry.permissions!.octal, '0755');
    expect(entry.owner, '501');
    expect(entry.group, '20');
    expect(entry.isHidden, isTrue);
    expect(
      entry.modifiedAt,
      DateTime.fromMillisecondsSinceEpoch(1780000000000, isUtc: true),
    );
  });

  test('maps root file path without duplicate slashes', () {
    final entry = DartSsh2SftpConnection.mapName(
      path: '/',
      name: ssh.SftpName(
        filename: 'app.log',
        longname: '',
        attr: ssh.SftpFileAttrs(
          size: 12,
          mode: ssh.SftpFileMode.value(int.parse('100640', radix: 8)),
        ),
      ),
    );

    expect(entry.path, '/app.log');
    expect(entry.type, SftpEntryType.file);
    expect(entry.permissions!.octal, '0640');
  });
}
