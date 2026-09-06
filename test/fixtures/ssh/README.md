# SSH and terminal interoperability fixture

This opt-in fixture connects Serlink's production SSH service and terminal
adapter to an independent SSH implementation (AsyncSSH). It binds only loopback,
generates disposable host/user keys, and keeps SFTP files in the fixture directory.
The default fixture responds to a small set of test messages without executing
shell commands. It does not read the app vault or existing SSH credentials.

```sh
python3 -m venv /tmp/serlink-ssh-venv
/tmp/serlink-ssh-venv/bin/pip install asyncssh==2.24.0
/tmp/serlink-ssh-venv/bin/python test/fixtures/ssh/server.py /tmp/serlink-ssh-fixture
```

In another terminal:

```sh
SERLINK_SSH_FIXTURE=/tmp/serlink-ssh-fixture \
  flutter test test/features/ssh/data/ssh_terminal_integration_test.dart
```

To also test a native OpenSSH PTY, start the fixture with
`--openssh /usr/sbin/sshd` (adjust the executable path for your OS). This runs a
separate sshd with an isolated config and disposable authorized key, on loopback
with password authentication disabled. Its forced `/bin/sh -i` session avoids
the user's interactive shell configuration. The test checks real command output,
PTY resize using `stty size`, and shell exit. The optional daemon is stopped when
the fixture exits; press Ctrl+C to stop the fixture.

Coverage: password, private-key and keyboard-interactive authentication; rejected
credentials and host keys; AES-GCM, ChaCha20, CTR and CBC; jump-host forwarding;
typed SSH byte streams through xterm with/without ZMODEM; Unicode, stderr, burst
output, window changes, exit, connection loss/reconnect; production SFTP service.
This does not exercise the OS SSH agent, hardware keys, real ZMODEM transfers,
or every server/algorithm combination.
