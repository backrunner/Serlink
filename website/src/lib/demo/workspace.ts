// The landing preview is entirely local: commands only read these sample records.
export const hosts = [
  { id: 'bastion', name: 'Bastion', address: 'bastion.example.test' },
  { id: 'build', name: 'Build Runner', address: 'build.example.test' },
  { id: 'db', name: 'Database', address: 'db.example.test' },
  { id: 'web', name: 'Production Web', address: 'web.example.test' }
];
export type Host = (typeof hosts)[number];
export type View = 'hosts' | 'terminal' | 'sftp' | 'transfers' | 'snippets' | 'settings';
export type Entry = { command: string; cwd: string; output: string; error?: boolean };
export type Terminal = { cwd: string; entries: Entry[]; history: string[]; draft: string };
export type SampleFile = { name: string; directory?: boolean; size: string; content?: string };

export const files: Record<string, SampleFile[]> = {
  '/': [{ name: 'srv', directory: true, size: '—' }],
  '/srv': [{ name: 'app', directory: true, size: '—' }],
  '/srv/app': [
    { name: 'config', directory: true, size: '—' },
    { name: 'releases', directory: true, size: '—' },
    { name: 'app.env', size: '86 B', content: 'APP_ENV=production\nAPP_PORT=8080\nLOG_LEVEL=info\n# Sample configuration — no credentials\n' },
    { name: 'README.md', size: '176 B', content: '# Production Web\n\nA sample workspace for the Serlink interactive demo.\n\nconfig/       Service configuration\nreleases/     Release manifests\nservice.log   Recent application logs\n' },
    { name: 'service.log', size: '218 B', content: '[09:41:00] INFO  Service started on :8080\n[09:41:01] INFO  Database connection ready\n[09:41:02] INFO  GET /health 200 2ms\n[09:41:03] INFO  GET /api/status 200 8ms\n[09:41:04] INFO  All health checks passed\n' }
  ],
  '/srv/app/config': [
    { name: 'nginx.conf', size: '119 B', content: 'server {\n    listen 80;\n    server_name web.example.test;\n\n    location / {\n        proxy_pass http://127.0.0.1:8080;\n    }\n}\n' }
  ],
  '/srv/app/releases': [
    { name: 'current.json', size: '76 B', content: '{\n  "version": "1.4.2",\n  "status": "healthy",\n  "deployedAt": "09:41:00"\n}\n' }
  ]
};

export const suggestions = ['help', 'uptime', 'ls -lh /srv/app', 'cat README.md'];
export const snippets = [
  { key: 'health', command: 'uptime' },
  { key: 'logs', command: 'cat /srv/app/service.log' },
  { key: 'release', command: 'cat /srv/app/releases/current.json' }
];

export function normalizePath(path: string, cwd: string): string {
  const parts: string[] = [];
  for (const part of (path.startsWith('/') ? path : `${cwd}/${path}`).split('/')) {
    if (part === '..') parts.pop();
    else if (part && part !== '.') parts.push(part);
  }
  return `/${parts.join('/')}`;
}

export function initialTerminal(): Terminal {
  return {
    cwd: '/srv/app', draft: '', history: [],
    entries: [
      { command: 'uptime', cwd: '/srv/app', output: '09:41:00 up 12 days, 3:18, 2 users\nload average: 0.12, 0.18, 0.16' },
      { command: 'ls -lh /srv/app', cwd: '/srv/app', output: listFiles('/srv/app', true) }
    ]
  };
}

function listFiles(path: string, long: boolean): string {
  return files[path].map((file) => long
    ? `${file.directory ? 'drwxr-xr-x' : '-rw-r-----'}  deploy ops  ${file.size.padStart(5)}  ${file.name}${file.directory ? '/' : ''}`
    : `${file.name}${file.directory ? '/' : ''}`).join(long ? '\n' : '  ');
}

export function execute(command: string, terminal: Terminal, host: Host, t: (key: string) => string): Terminal {
  const input = command.trim();
  if (!input) return terminal;
  const [program, ...args] = input.split(/\s+/);
  let cwd = terminal.cwd;
  let output = '';
  let error = false;
  switch (program) {
    case 'help': output = t('demo.helpOutput'); break;
    case 'uptime': output = '09:41:00 up 12 days, 3:18, 2 users\nload average: 0.12, 0.18, 0.16'; break;
    case 'pwd': output = cwd; break;
    case 'whoami': output = 'ops'; break;
    case 'hostname': output = host.address; break;
    case 'ls': {
      const path = normalizePath(args.find((arg) => !arg.startsWith('-')) ?? '.', cwd);
      if (files[path]) output = listFiles(path, args.some((arg) => arg.startsWith('-') && arg.includes('l')));
      else { error = true; output = `${t('demo.missingPath')}: ${path}`; }
      break;
    }
    case 'cd': {
      const path = normalizePath(args[0] ?? '/srv/app', cwd);
      if (files[path]) cwd = path;
      else { error = true; output = `${t('demo.missingPath')}: ${path}`; }
      break;
    }
    case 'cat': {
      const path = normalizePath(args[0] ?? '', cwd);
      const slash = path.lastIndexOf('/');
      const file = files[path.slice(0, slash) || '/']?.find((file) => file.name === path.slice(slash + 1) && !file.directory);
      if (file) output = file.content ?? '';
      else { error = true; output = `${t('demo.missingFile')}: ${path}`; }
      break;
    }
    case 'clear': break;
    default: error = true; output = t('demo.unsupported');
  }
  return {
    cwd, draft: '', history: [...terminal.history, input].slice(-50),
    entries: program === 'clear' ? [] : [...terminal.entries, { command: input, cwd: terminal.cwd, output, error }].slice(-60)
  };
}
