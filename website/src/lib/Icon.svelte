<script lang="ts">
  export let name = 'arrow';
  export let size = 20;
  const paths: Record<string, string> = {
    arrow: 'M5 12h14m-6-6 6 6-6 6', down: 'M12 4v16m-6-6 6 6 6-6',
    terminal: 'm5 7 5 5-5 5m8 0h6', folder: 'M3 7h6l2-3h10v16H3Z',
    shield: 'm12 3 8 3v6c0 5-8 9-8 9S4 17 4 12V6Z',
    lock: 'M7 10V7a5 5 0 0 1 10 0v3M5 10h14v11H5Zm7 4v3',
    hosts: 'M3 3h18v7H3Zm0 11h18v7H3ZM7 6h.01M7 17h.01',
    key: 'M15 12a5 5 0 1 0-3-3L3 18v3h3v-3h3v-3Z',
    cloud: 'M6 18a5 5 0 0 1 0-10 6 6 0 0 1 11-2 5 5 0 0 1 1 12Z',
    check: 'm5 12 4 4L19 6', code: 'm8 5-7 7 7 7m8-14 7 7-7 7',
    sun: 'M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5M16 12a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
    moon: 'M20 15A9 9 0 0 1 9 4 9 9 0 1 0 20 15',
    system: 'M3 3h18v14H3Zm9 14v4m-4 0h8',
    menu: 'M4 6h16M4 12h16M4 18h16', close: 'm6 6 12 12M18 6 6 18',
    search: 'M16 16l5 5M17 10A7 7 0 1 1 3 10a7 7 0 0 1 14 0',
    mail: 'M3 5h18v14H3Zm0 0 9 8 9-8', globe: 'M2 12h20M12 2c6 6 6 14 0 20-6-6-6-14 0-20M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0'
  };
</script>
<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d={paths[name] ?? paths.arrow} /></svg>
