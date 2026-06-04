# SFTP integration fixture

This fixture starts a local OpenSSH server with password auth and SFTP enabled.
It is only for opt-in integration tests; normal `flutter test` skips these tests.

Run the fixture:

```sh
docker compose -f test/fixtures/sftp/docker-compose.yml up --build
```

In another terminal, run:

```sh
SERLINK_SFTP_INTEGRATION=1 flutter test test/features/sftp/data/dartssh2_sftp_connection_integration_test.dart
```

Defaults:

- Host: `127.0.0.1`
- Port: `2222`
- User: `serlink`
- Password: `serlink`
- Remote root: `/home/serlink/workspace`

Override any value with `SERLINK_SFTP_HOST`, `SERLINK_SFTP_PORT`,
`SERLINK_SFTP_USER`, `SERLINK_SFTP_PASSWORD`, or `SERLINK_SFTP_ROOT`.
