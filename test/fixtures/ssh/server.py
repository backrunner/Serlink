"""Loopback-only SSH interoperability fixture using ephemeral test keys.

Install asyncssh in a venv and pass a temporary directory as the first argument.
No user credentials, SSH configuration, or real shell commands are used.
"""
import asyncio
import argparse
import getpass
import json
import pathlib
import socket

import asyncssh


async def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--openssh", help="Optional absolute path to a local sshd executable")
    args = parser.parse_args()
    root = args.directory.resolve()
    root.mkdir(parents=True, exist_ok=True)
    (root / "workspace").mkdir(exist_ok=True)
    host_key = asyncssh.generate_private_key("ssh-ed25519")
    user_key = asyncssh.generate_private_key("ssh-ed25519")
    (root / "user_key").write_bytes(user_key.export_private_key("openssh"))
    (root / "user_key").chmod(0o600)
    native = None
    (root / "openssh.json").unlink(missing_ok=True)
    if args.openssh:
        (root / "openssh_host").write_bytes(host_key.export_private_key("openssh"))
        (root / "openssh_host").chmod(0o600)
        (root / "authorized_keys").write_bytes(user_key.export_public_key())
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            native_port = sock.getsockname()[1]
        username = getpass.getuser()
        config = root / "sshd_config"
        config.write_text("\n".join([
            "ListenAddress 127.0.0.1", f"Port {native_port}",
            f'HostKey "{root}/openssh_host"', f'PidFile "{root}/sshd.pid"',
            f'AuthorizedKeysFile "{root}/authorized_keys"', "StrictModes no",
            "UsePAM no", "PasswordAuthentication no", "KbdInteractiveAuthentication no",
            f"AllowUsers {username}", "ForceCommand /bin/sh -i", "LogLevel ERROR", "",
        ]))
        native = await asyncio.create_subprocess_exec(args.openssh, "-D", "-e", "-f", str(config))
        await asyncio.sleep(0.2)
        if native.returncode is not None:
            raise RuntimeError("Local OpenSSH fixture could not start")
        (root / "openssh.json").write_text(json.dumps({
            "port": native_port, "username": username,
            "fingerprint": host_key.get_fingerprint(),
        }))

    class Server(asyncssh.SSHServer):
        def begin_auth(self, username):
            return True

        def password_auth_supported(self):
            return True

        def validate_password(self, username, password):
            return username == "serlink-test" and password == "fixture-only"

        def public_key_auth_supported(self):
            return True

        def validate_public_key(self, username, key):
            return username == "serlink-test" and key.export_public_key() == user_key.export_public_key()

        def kbdint_auth_supported(self):
            return True

        def get_kbdint_challenge(self, username, lang, submethods):
            return "", "", "", [("Test response:", False)]

        def validate_kbdint_response(self, username, responses):
            return username == "serlink-test" and responses == ["fixture-only"]

        def connection_requested(self, dest_host, dest_port, orig_host, orig_port):
            return dest_host == "127.0.0.1" and dest_port in ports.values()

    async def shell(process):
        process.stdout.write("fixture-ready\r\n")
        try:
            while True:
                try:
                    line = await process.stdin.readline()
                except asyncssh.TerminalSizeChanged:
                    continue
                if not line:
                    return
                command = line.strip()
                if command == "exit":
                    process.stdout.write("fixture-exit\r\n")
                    process.exit(7)
                    return
                if command == "drop":
                    process.channel.get_connection().abort()
                    return
                if command == "size":
                    width, height, _, _ = process.get_terminal_size()
                    process.stdout.write(f"size:{width}x{height}\r\n")
                elif command == "unicode":
                    process.stdout.write("\x1b[32m中文🙂\x1b[0m\r\n")
                    process.stderr.write("stderr-ok\r\n")
                elif command == "burst":
                    process.stdout.write("".join(f"line-{i:04d}\r\n" for i in range(3000)))
                else:
                    process.stdout.write(f"echo:{command}\r\n")
        except (asyncssh.ConnectionLost, BrokenPipeError):
            pass

    servers = []
    ports = {}
    for name, cipher in {
        "gcm": "aes256-gcm@openssh.com",
        "chacha": "chacha20-poly1305@openssh.com",
        "ctr": "aes256-ctr",
        "cbc": "aes128-cbc",
    }.items():
        server = await asyncssh.create_server(
            Server, "127.0.0.1", 0,
            server_host_keys=[host_key],
            encryption_algs=[cipher],
            process_factory=shell,
            sftp_factory=lambda channel: asyncssh.SFTPServer(channel, chroot=root),
            line_editor=False,
        )
        servers.append(server)
        ports[name] = server.get_port()
    settings = {"ports": ports, "fingerprint": host_key.get_fingerprint()}
    (root / "fixture.json").write_text(json.dumps(settings))
    print(json.dumps(settings), flush=True)
    try:
        await asyncio.Future()
    finally:
        if native is not None and native.returncode is None:
            native.terminate()
            await native.wait()
        (root / "openssh.json").unlink(missing_ok=True)
        for server in servers:
            server.close()
        await asyncio.gather(*(server.wait_closed() for server in servers))


try:
    asyncio.run(main())
except KeyboardInterrupt:
    pass
