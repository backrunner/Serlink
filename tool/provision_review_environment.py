#!/usr/bin/env python3
"""Provision a dedicated Ubuntu review host over an existing admin session.

Run as root on the review machine. No credential is accepted on the command
line or printed. The generated connection details are written to a root-only
JSON file, for private App Review Information only. Never commit that file.
This intentionally fails if the review account or jail already exists.
"""
import argparse
import json
import os
from pathlib import Path
import pwd
import re
import secrets
import string
import shutil
import subprocess


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def write(path, text, mode=0o644):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    path.chmod(mode)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', required=True)
    parser.add_argument('--username', required=True)
    parser.add_argument('--private-output', default='/root/serlink-review-access.json')
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise SystemExit('Run as root on the dedicated review machine')
    if not re.fullmatch(r'[a-z][a-z0-9_]{2,20}', args.username):
        raise SystemExit('Invalid account name')
    if not re.fullmatch(r'[A-Za-z0-9.:-]+', args.host):
        raise SystemExit('Invalid host')
    account = args.username
    jail = Path('/srv/serlink-review/jail')
    private = Path(args.private_output)
    try:
        pwd.getpwnam(account)
    except KeyError:
        pass
    else:
        raise SystemExit('Account already exists; inspect it before changing credentials')
    if jail.exists() or private.exists():
        raise SystemExit('Existing review data found; inspect before provisioning')
    for binary in ['bash', 'busybox', 'nft', 'mount', 'sshd', 'python3']:
        if shutil.which(binary) is None:
            raise SystemExit(f'Required system binary is missing: {binary}')
    run('useradd', '--no-create-home', '--home-dir', '/workspace', '--shell', '/bin/bash', account)
    user = pwd.getpwnam(account)
    password = ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(32))
    write(private, json.dumps({'host': args.host, 'port': 22, 'username': account,
          'password': password, 'sftpDirectory': '/workspace', 'status': 'provisioning'}, indent=2) + '\n', 0o600)
    run('chpasswd', input=f'{account}:{password}\n', stdout=subprocess.DEVNULL)
    run('usermod', '--groups', '', account)
    jail.mkdir(parents=True, mode=0o755)
    for name in ['bin', 'lib', 'lib64', 'etc', 'dev', 'usr/lib/openssh', 'workspace']:
        (jail / name).mkdir(parents=True, exist_ok=True)

    def copy_binary(source, destination):
        target = jail / destination.lstrip('/')
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        target.chmod(0o755)
        result = subprocess.run(['ldd', source], text=True, capture_output=True)
        for library in re.findall(r'(?<!\S)(/[^\s()]+)', result.stdout):
            dest = jail / library.lstrip('/')
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(library, dest)
            dest.chmod(0o755)

    copy_binary(shutil.which('bash'), '/bin/bash')
    copy_binary(shutil.which('busybox'), '/bin/busybox')
    copy_binary('/usr/lib/openssh/sftp-server', '/usr/lib/openssh/sftp-server')
    applets = ['sh', 'ls', 'cat', 'pwd', 'mkdir', 'rmdir', 'touch', 'rm', 'mv', 'cp',
               'chmod', 'head', 'tail', 'wc', 'sort', 'grep', 'sed', 'find', 'date',
               'uname', 'id', 'whoami', 'stat', 'du', 'df', 'sleep', 'printf',
               'env', 'printenv', 'clear', 'vi', 'true', 'false', 'cut', 'tee']
    for name in applets:
        (jail / 'bin' / name).symlink_to('busybox')
    write(jail / 'etc/passwd', f'root:x:0:0:root:/root:/bin/bash\n{account}:x:{user.pw_uid}:{user.pw_gid}:App Review:/workspace:/bin/bash\n')
    write(jail / 'etc/group', f'root:x:0:\n{account}:x:{user.pw_gid}:\n')
    write(jail / 'etc/nsswitch.conf', 'passwd: files\ngroup: files\nhosts: files\n')
    write(jail / 'etc/hosts', '127.0.0.1 localhost review-sandbox\n')
    write(jail / 'etc/profile', 'export PATH=/bin\nexport HOME=/workspace\nexport TERM=${TERM:-xterm-256color}\nexport PS1="reviewer@review-sandbox:\\w\\$ "\numask 077\nulimit -c 0\nulimit -u 64\nulimit -n 128\nulimit -f 65536\ncd /workspace\n[ -f /workspace/README.txt ] && cat /workspace/README.txt\n')
    # Only these harmless devices exist. No host filesystem or /proc is mounted.
    for name, minor in [('null', 3), ('zero', 5), ('random', 8), ('urandom', 9), ('tty', 0)]:
        major = 5 if name == 'tty' else 1
        run('mknod', '-m', '666', str(jail / 'dev' / name), 'c', str(major), str(minor))
    workspace = jail / 'workspace'
    mount_unit = run('systemd-escape', '--path', '--suffix=mount', str(workspace), capture_output=True).stdout.strip()
    write(f'/etc/systemd/system/{mount_unit}',
          '[Unit]\nDescription=Bounded temporary Serlink review files\nBefore=ssh.service\n'
          f'[Mount]\nWhat=tmpfs\nWhere={workspace}\nType=tmpfs\n'
          f'Options=size=256M,nr_inodes=8192,nosuid,nodev,noexec,mode=0700,uid={user.pw_uid},gid={user.pw_gid}\n'
          '[Install]\nWantedBy=multi-user.target\n')
    run('systemctl', 'daemon-reload')
    run('systemctl', 'enable', '--now', mount_unit)
    examples = {
        'README.txt': 'Serlink real SSH/SFTP review sandbox\n\n'
            'You are signed in to a dedicated restricted review account.\n'
            'Try: pwd; ls -la; whoami; uname -a; cat documents/notes.txt\n'
            'Create, edit, upload, download, rename and remove files in /workspace.\n'
            'SFTP starts at /workspace. Use disposable files.\n'
            'sudo and access to administrator files are intentionally unavailable.\n'
            'Port forwarding may reach only 127.0.0.1:8080, a sample HTTP service.\n',
        'documents/notes.txt': 'Review checklist\n\nPreview and edit this text file.\nUpload to uploads and download README.txt.\nCreate a folder, rename a file and inspect file permissions.\n',
        'documents/example.json': '{"service":"Serlink App Review","status":"ready"}\n',
        'logs/application.log': 'INFO review sandbox ready\nINFO SSH terminal and SFTP enabled\n',
    }
    for name in ['documents', 'uploads', 'logs']:
        directory = workspace / name
        directory.mkdir(mode=0o700)
        os.chown(directory, user.pw_uid, user.pw_gid)
    for name, content in examples.items():
        file = workspace / name
        write(file, content, 0o600)
        os.chown(file, user.pw_uid, user.pw_gid)
    seed_source = "import os\nfrom pathlib import Path\n" + f"base = Path({str(workspace)!r})\nuid = {user.pw_uid}\ngid = {user.pw_gid}\nexamples = {examples!r}\n" + """for name, content in examples.items():
    target = base / name
    target.parent.mkdir(parents=True, exist_ok=True)
    os.chown(target.parent, uid, gid)
    if not target.exists():
        target.write_text(content)
        target.chmod(0o600)
        os.chown(target, uid, gid)
(base / 'uploads').mkdir(exist_ok=True)
os.chown(base / 'uploads', uid, gid)
"""
    # The seeder must run as the confined account, never as root: writable
    # workspace symlinks must not turn a manual reseed into host root writes.
    seed_source = seed_source.replace('    os.chown(target.parent, uid, gid)\n', '').replace('        os.chown(target, uid, gid)\n', '').replace("os.chown(base / 'uploads', uid, gid)\n", '')
    write('/usr/local/libexec/serlink-review-seed.py', seed_source, 0o755)
    write('/etc/systemd/system/serlink-review-seed.service',
          f'[Unit]\nDescription=Seed disposable Serlink review files\nRequires={mount_unit}\nAfter={mount_unit}\nBefore=ssh.service\n'
          f'[Service]\nType=oneshot\nUser={account}\nGroup={account}\n'
          f'ProtectSystem=strict\nProtectHome=yes\nReadWritePaths={workspace}\n'
          'PrivateTmp=yes\nPrivateNetwork=yes\nNoNewPrivileges=yes\n'
          'ExecStart=/usr/bin/python3 /usr/local/libexec/serlink-review-seed.py\n'
          '[Install]\nWantedBy=multi-user.target\n')
    write(f'/etc/security/limits.d/90-serlink-review.conf',
          f'{account} hard nproc 64\n{account} hard nofile 128\n{account} hard fsize 65536\n{account} hard core 0\n')
    write(f'/etc/systemd/system/user-{user.pw_uid}.slice.d/limits.conf',
          '[Slice]\nTasksMax=64\nMemoryMax=256M\nCPUQuota=50%\nSocketBindDeny=any\n')
    # Applies only to the review UID, for IPv4 and IPv6. Established SSH replies
    # remain allowed; new outgoing connections may reach only the demo service.
    rules = f'''table inet serlink_review {{
 chain output {{
  type filter hook output priority 0; policy accept;
  meta skuid {user.pw_uid} ct state established,related accept
  meta skuid {user.pw_uid} ip daddr 127.0.0.1 tcp dport 8080 accept
  meta skuid {user.pw_uid} reject
 }}
}}
'''
    write('/etc/serlink-review.nft', rules, 0o600)
    write('/etc/systemd/system/serlink-review-firewall.service',
          '[Unit]\nDescription=Serlink review account egress isolation\nBefore=ssh.service\nAfter=network-pre.target\n'
          '[Service]\nType=oneshot\nRemainAfterExit=yes\nExecStartPre=-/usr/sbin/nft delete table inet serlink_review\n'
          'ExecStart=/usr/sbin/nft -f /etc/serlink-review.nft\n'
          '[Install]\nWantedBy=multi-user.target\n')
    web = Path('/var/lib/serlink-review/web')
    write(web / 'index.html', '<!doctype html><title>Serlink Review</title><h1>SSH tunnel connected</h1><p>This is the dedicated Serlink review service.</p>')
    web.chmod(0o755)
    # The web service receives only its static directory through a read-only mount.
    write('/etc/systemd/system/serlink-review-web.service',
          '[Unit]\nDescription=Serlink sample tunnel target\nAfter=network.target\n'
          '[Service]\nDynamicUser=yes\nExecStart=/usr/bin/python3 -m http.server 8080 --bind 127.0.0.1 --directory /srv/review-web\n'
          f'BindReadOnlyPaths={web}:/srv/review-web\n'
          'ProtectSystem=strict\nProtectHome=yes\nPrivateTmp=yes\nPrivateDevices=yes\n'
          'NoNewPrivileges=yes\nRestrictSUIDSGID=yes\nRestrictNamespaces=yes\n'
          'CapabilityBoundingSet=\nMemoryMax=64M\nTasksMax=16\n'
          'Restart=on-failure\n[Install]\nWantedBy=multi-user.target\n')
    # Use a Match block, never globally enable password login or forwarding.
    config = f'''Match User {account}
    ChrootDirectory {jail}
    PasswordAuthentication yes
    KbdInteractiveAuthentication no
    AuthenticationMethods password
    PubkeyAuthentication no
    PermitTTY yes
    PermitUserRC no
    AllowAgentForwarding no
    X11Forwarding no
    PermitTunnel no
    AllowStreamLocalForwarding no
    AllowTcpForwarding local
    PermitOpen 127.0.0.1:8080
    PermitListen none
    GatewayPorts no
    MaxAuthTries 3
    MaxSessions 4
Match all
'''
    config_path = Path('/etc/ssh/sshd_config.d/90-serlink-review.conf')
    write(config_path, config, 0o600)
    try:
        run('/usr/sbin/sshd', '-t')
    except subprocess.CalledProcessError:
        config_path.unlink()
        run('/usr/sbin/sshd', '-t')
        raise
    run('systemctl', 'daemon-reload')
    run('systemctl', 'enable', '--now', 'serlink-review-seed.service', 'serlink-review-firewall.service', 'serlink-review-web.service')
    run('systemctl', 'reload', 'ssh')
    fingerprints = []
    for key in Path('/etc/ssh').glob('ssh_host_*_key.pub'):
        fingerprints.append(run('ssh-keygen', '-lf', str(key), capture_output=True).stdout.strip())
    write(private, json.dumps({'host': args.host, 'port': 22, 'username': account,
          'password': password, 'sftpDirectory': '/workspace', 'fingerprints': fingerprints}, indent=2) + '\n', 0o600)
    print(f'Review environment provisioned. Private credentials: {private}')


if __name__ == '__main__':
    main()
