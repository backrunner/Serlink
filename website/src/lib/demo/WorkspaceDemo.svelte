<script lang="ts">
  import { onMount, tick } from 'svelte';
  import type { SvedocsThemeContext } from 'svedocs/theme/types';
  import Icon from '../Icon.svelte';
  import { execute, files, hosts, initialTerminal, normalizePath, snippets, suggestions, type Host, type SampleFile, type Terminal, type View } from './workspace';

  export let context: SvedocsThemeContext;
  type Session = { id: string; hostId: string; kind: 'terminal' | 'sftp' };
  type Transfer = { id: number; name: string; host: string; size: string; path: string };
  const initialSession: Session = { id: 'web-terminal', hostId: 'web', kind: 'terminal' };
  const navigation = [
    { view: 'hosts', icon: 'hosts', key: 'hosts' },
    { view: 'terminal', icon: 'terminal', key: 'sessions' },
    { view: 'transfers', icon: 'transfer', key: 'transfers' },
    { view: 'snippets', icon: 'code', key: 'snippets' },
    { view: 'settings', icon: 'settings', key: 'settings' }
  ] as const;
  let ready = false;
  let view: View = 'terminal';
  let sessions: Session[] = [{ ...initialSession }];
  let activeSession = initialSession.id;
  let hostId = 'web';
  let terminals: Record<string, Terminal> = Object.fromEntries(hosts.map((host) => [host.id, initialTerminal()]));
  let directories: Record<string, string> = {};
  let hostQuery = '';
  let fileQuery = '';
  let filePreview: SampleFile | undefined;
  let fileButtons: Record<string, HTMLButtonElement> = {};
  let transfers: Transfer[] = [];
  let transferId = 0;
  let announcement = '';
  let fontSize = 13;
  let historyIndex = -1;
  let savedDraft = '';
  let commandInput: HTMLInputElement;
  let terminalScroll: HTMLDivElement;
  let fileClose: HTMLButtonElement;
  $: t = context.t;
  $: locale = ['en', 'zh', 'ja'].includes(context.localeCode) ? context.localeCode : 'en';
  $: host = hosts.find((item) => item.id === hostId)!;
  $: terminal = terminals[hostId];
  $: directory = directories[hostId] ?? '/srv/app';
  $: matchingHosts = hosts.filter((item) => `${item.name} ${item.address}`.toLowerCase().includes(hostQuery.toLowerCase()));
  $: matchingFiles = files[directory].filter((item) => item.name.toLowerCase().includes(fileQuery.toLowerCase()));
  onMount(() => { ready = true; });

  function setView(next: View) {
    filePreview = undefined;
    announcement = '';
    if (next === 'terminal' || next === 'sftp') openSession(host, next);
    else view = next;
  }

  function openSession(nextHost: Host, kind: 'terminal' | 'sftp') {
    const id = `${nextHost.id}-${kind}`;
    if (!sessions.some((session) => session.id === id)) sessions = [...sessions, { id, hostId: nextHost.id, kind }];
    selectSession(sessions.find((session) => session.id === id)!);
  }

  function selectSession(session: Session) {
    activeSession = session.id;
    hostId = session.hostId;
    view = session.kind;
    filePreview = undefined;
    fileQuery = '';
    historyIndex = -1;
    announcement = '';
  }

  async function closeSession(id: string) {
    const index = sessions.findIndex((session) => session.id === id);
    sessions = sessions.filter((session) => session.id !== id);
    if (activeSession === id) {
      const next = sessions[Math.min(index, sessions.length - 1)];
      if (next) selectSession(next);
      else view = 'hosts';
    }
    await tick();
    if (view === 'terminal') commandInput?.focus({ preventScroll: true });
  }

  async function run(command: string) {
    if (!command.trim()) return;
    openSession(host, 'terminal');
    terminals = { ...terminals, [hostId]: execute(command, terminals[hostId], host, t) };
    historyIndex = -1;
    await tick();
    terminalScroll.scrollTop = terminalScroll.scrollHeight;
    commandInput.focus({ preventScroll: true });
  }

  function commandKey(event: KeyboardEvent) {
    if (event.isComposing) return;
    const history = terminal.history;
    if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
      event.preventDefault();
      if (historyIndex === -1) savedDraft = terminal.draft;
      historyIndex = event.key === 'ArrowUp'
        ? Math.min(historyIndex + 1, history.length - 1)
        : Math.max(historyIndex - 1, -1);
      terminal.draft = historyIndex === -1 ? savedDraft : history[history.length - 1 - historyIndex];
    } else if (event.key === 'Tab' && terminal.draft.trim()) {
      const commands = ['help', 'uptime', 'pwd', 'whoami', 'hostname', 'ls', 'cd', 'cat', 'clear'];
      const matches = commands.filter((command) => command.startsWith(terminal.draft));
      // Do not trap Tab: only consume it when there is one useful completion.
      if (matches.length === 1 && matches[0] !== terminal.draft) {
        event.preventDefault();
        terminal.draft = matches[0];
      }
    } else if (event.ctrlKey && event.key === 'l') {
      event.preventDefault();
      void run('clear');
    }
  }

  async function openFile(file: SampleFile) {
    if (file.directory) {
      directories = { ...directories, [hostId]: normalizePath(file.name, directory) };
      fileQuery = '';
    } else {
      filePreview = file;
      await tick();
      fileClose.focus({ preventScroll: true });
    }
  }

  async function closeFile() {
    const name = filePreview?.name;
    filePreview = undefined;
    await tick();
    if (name) fileButtons[name]?.focus({ preventScroll: true });
  }

  function previewKey(event: KeyboardEvent) {
    if (event.key === 'Escape') { event.stopPropagation(); void closeFile(); }
  }

  function download(file: SampleFile) {
    transfers = [{ id: ++transferId, name: file.name, host: host.name, size: file.size, path: `${directory}/${file.name}` }, ...transfers].slice(0, 20);
    announcement = `${file.name} — ${t('demo.downloaded')}`;
  }

  function reset() {
    sessions = [{ ...initialSession }];
    activeSession = initialSession.id;
    hostId = 'web';
    view = 'terminal';
    terminals = Object.fromEntries(hosts.map((host) => [host.id, initialTerminal()]));
    directories = {};
    transfers = [];
    filePreview = undefined;
    fileQuery = hostQuery = announcement = '';
    fontSize = 13;
    historyIndex = -1;
  }
</script>

<section class="sl-showcase" aria-label={t('demo.label')}>
  <div class="sl-showcase-bar">
    <span class="sl-label">{t('demo.label')}</span>
    <div class="sl-preview-switcher" role="group" aria-label={t('preview.switch')}>
      {#each [{ view: 'hosts', icon: 'hosts' }, { view: 'terminal', icon: 'terminal' }, { view: 'sftp', icon: 'folder' }] as item}
        <button type="button" disabled={!ready} aria-pressed={view === item.view} class:sl-selected={view === item.view} on:click={() => setView(item.view as View)}>
          <Icon name={item.icon} size={16} /><span>{t(`preview.${item.view}`)}</span>
        </button>
      {/each}
    </div>
  </div>

  {#if !ready}
    <div class="demo-fallback"><img src={`/screenshots/${locale}/02-terminal.jpg`} width="2560" height="1600" alt={t('preview.terminal.alt')} fetchpriority="high" /></div>
  {:else}
    <div class="demo-shell" style={`--demo-font-size: ${fontSize}px`} data-view={view}>
      <aside class="demo-sidebar">
        <div class="demo-window-controls" aria-hidden="true"><i></i><i></i><i></i></div>
        <nav aria-label={t('demo.nav')}>
          {#each navigation as item}
            <button type="button" class:current={view === item.view || (item.view === 'terminal' && view === 'sftp')} class:settings={item.view === 'settings'} aria-pressed={view === item.view || (item.view === 'terminal' && view === 'sftp')} title={t(`demo.${item.key}`)} on:click={() => setView(item.view)}>
              <Icon name={item.icon} size={19} /><span>{t(`demo.${item.key}`)}</span>
              {#if item.view === 'transfers' && transfers.length}<small>{transfers.length}</small>{/if}
            </button>
          {/each}
        </nav>
      </aside>

      <div class="demo-workspace">
        {#if view === 'terminal' || view === 'sftp'}
          <div class="demo-session-bar">
            <div class="demo-tabs" role="group" aria-label={t('demo.tabs')}>
              {#each sessions as session (session.id)}
                {@const sessionHost = hosts.find((host) => host.id === session.hostId)!}
                <div class="demo-tab" class:active={session.id === activeSession}>
                  <button type="button" class="demo-tab-select" aria-pressed={session.id === activeSession} on:click={() => selectSession(session)} title={`${sessionHost.name} · ${t(`demo.${session.kind === 'sftp' ? 'files' : 'terminal'}`)}`}>
                    <Icon name={session.kind === 'sftp' ? 'folder' : 'terminal'} size={15} /><span>{sessionHost.name}{session.kind === 'sftp' ? ' /' : ''}</span>
                  </button>
                  <button type="button" class="demo-close-tab" aria-label={`${t('demo.closeSession')}: ${sessionHost.name} ${t(`demo.${session.kind === 'sftp' ? 'files' : 'terminal'}`)}`} on:click={() => closeSession(session.id)}><Icon name="close" size={13} /></button>
                </div>
              {/each}
            </div>
            <button type="button" class="demo-icon demo-add" aria-label={t('demo.newSession')} title={t('demo.newSession')} on:click={() => setView('hosts')}><Icon name="plus" size={18} /></button>
            <div class="demo-session-tools">
              <button type="button" class="demo-icon" aria-label={t('demo.snippets')} title={t('demo.snippets')} on:click={() => setView('snippets')}><Icon name="code" size={18} /></button>
              <button type="button" class="demo-icon" aria-label={t(view === 'terminal' ? 'demo.files' : 'demo.terminal')} title={t(view === 'terminal' ? 'demo.files' : 'demo.terminal')} on:click={() => setView(view === 'terminal' ? 'sftp' : 'terminal')}><Icon name={view === 'terminal' ? 'folder' : 'terminal'} size={18} /></button>
            </div>
          </div>
        {:else}
          <header class="demo-heading">
            <h3>{t(`demo.${view}`)}{#if view === 'hosts'}<small>{hosts.length}</small>{/if}</h3>
            {#if view === 'hosts'}
              <label class="demo-search"><Icon name="search" size={15} /><input aria-label={t('demo.searchHosts')} placeholder={t('demo.searchHosts')} bind:value={hostQuery} /></label>
            {:else if view === 'transfers' && transfers.length}
              <button type="button" class="demo-text-button" on:click={() => { transfers = []; announcement = ''; }}>{t('demo.clearTransfers')}</button>
            {/if}
          </header>
        {/if}

        {#if view === 'terminal'}
          <div class="demo-terminal">
            <div class="demo-terminal-scroll" bind:this={terminalScroll}>
              <div class="demo-output" role="log" aria-label={t('demo.output')} aria-live="polite" aria-relevant="additions">
                {#each terminal.entries as entry}
                  <div class="demo-entry">
                    <div class="demo-command-line"><span class="demo-prompt">ops@{host.address}</span> <span class="demo-cwd">{entry.cwd}</span> <span class="demo-dollar">%</span> {entry.command}</div>
                    {#if entry.output}<pre class:error={entry.error}>{entry.output}</pre>{/if}
                  </div>
                {/each}
              </div>
              <form class="demo-command-form" on:submit|preventDefault={() => run(terminal.draft)}>
                <label for="demo-command"><span class="demo-prompt">ops@{host.address}</span> <span class="demo-cwd">{terminal.cwd}</span> <span class="demo-dollar">%</span></label>
                <div class="demo-command-input"><input id="demo-command" bind:this={commandInput} bind:value={terminal.draft} on:keydown={commandKey} on:input={() => historyIndex = -1} aria-label={t('demo.command')} maxlength="240" autocomplete="off" autocapitalize="off" spellcheck="false" enterkeyhint="send" /><button type="submit" class="demo-icon" aria-label={t('demo.run')} title={t('demo.run')}><Icon name="return" size={16} /></button></div>
              </form>
            </div>
            <div class="demo-suggestions"><span>{t('demo.hint')}</span>{#each suggestions as command}<button type="button" on:click={() => run(command)}>{command}</button>{/each}</div>
          </div>
        {:else if view === 'hosts'}
          <div class="demo-content demo-host-list">
            {#each matchingHosts as item}
              <div class="demo-host">
                <Icon name="hosts" size={20} />
                <div class="demo-host-copy"><strong>{item.name}</strong><span>ops@{item.address}:22</span></div>
                <div class="demo-host-actions"><button type="button" class="demo-button primary" aria-label={`${t('demo.terminal')}: ${item.name}`} on:click={() => openSession(item, 'terminal')}><Icon name="terminal" size={16} /><span>{t('demo.terminal')}</span></button><button type="button" class="demo-button" aria-label={`SFTP: ${item.name}`} on:click={() => openSession(item, 'sftp')}><Icon name="folder" size={16} /><span>SFTP</span></button></div>
              </div>
            {:else}<p class="demo-empty">{t('demo.noHosts')}</p>{/each}
          </div>
        {:else if view === 'sftp'}
          {#if filePreview}
            <section class="demo-file-preview" aria-label={t('demo.preview')}>
              <header><Icon name="file" size={17} /><strong>{filePreview.name}</strong><button type="button" class="demo-icon" bind:this={fileClose} aria-label={t('demo.closeFile')} on:click={closeFile} on:keydown={previewKey}><Icon name="close" size={17} /></button></header>
              <textarea readonly aria-label={filePreview.name} value={filePreview.content} on:keydown={previewKey}></textarea>
            </section>
          {:else}
            <div class="demo-file-toolbar">
              <button type="button" class="demo-icon" disabled={directory === '/'} aria-label={t('demo.up')} title={t('demo.up')} on:click={() => { directories = { ...directories, [hostId]: normalizePath('..', directory) }; fileQuery = ''; }}><Icon name="up" size={18} /></button>
              <code>{directory}</code>
              <label class="demo-search"><Icon name="search" size={15} /><input aria-label={t('demo.searchFiles')} placeholder={t('demo.searchFiles')} bind:value={fileQuery} /></label>
            </div>
            <div class="demo-content demo-file-list">
              {#each matchingFiles as file}
                <div class="demo-file-row">
                  <button type="button" class="demo-file-open" bind:this={fileButtons[file.name]} on:click={() => openFile(file)}>
                    <Icon name={file.directory ? 'folder' : 'file'} size={20} /><span><strong>{file.name}</strong><small>{t(file.directory ? 'demo.folder' : 'demo.file')} · deploy:ops</small></span>
                  </button>
                  <span class="demo-file-size">{file.size}</span><code class="demo-permissions">{file.directory ? 'rwxr-xr-x' : 'rw-r-----'}</code>
                  {#if !file.directory}<button type="button" class="demo-icon" aria-label={`${t('demo.download')}: ${file.name}`} title={t('demo.download')} on:click={() => download(file)}><Icon name="down" size={17} /></button>{:else}<span class="demo-folder-spacer"></span>{/if}
                </div>
              {:else}<p class="demo-empty">{t('demo.noFiles')}</p>{/each}
            </div>
          {/if}
          <div class="demo-transfer-feedback" role="status">{announcement}</div>
        {:else if view === 'transfers'}
          <div class="demo-content">
            {#if transfers.length}
              {#each transfers as transfer (transfer.id)}
                <div class="demo-transfer-row"><Icon name="check" size={20} /><div><strong>{transfer.name}</strong><span>{transfer.host} · {transfer.size}</span><small>{transfer.path}</small></div><span class="demo-complete">{t('demo.complete')}</span></div>
              {/each}
            {:else}
              <div class="demo-empty"><Icon name="transfer" size={30} /><h4>{t('demo.emptyTransfers')}</h4><p>{t('demo.transferHint')}</p><button type="button" class="demo-button" on:click={() => setView('sftp')}>{t('demo.browseFiles')}<Icon name="arrow" size={16} /></button></div>
            {/if}
          </div>
        {:else if view === 'snippets'}
          <div class="demo-content"><p class="demo-description">{t('demo.snippetHint')}</p>{#each snippets as snippet}<button type="button" class="demo-snippet" on:click={() => run(snippet.command)}><Icon name="code" size={19} /><span><strong>{t(`demo.${snippet.key}`)}</strong><code>{snippet.command}</code></span><Icon name="play" size={17} /></button>{/each}</div>
        {:else if view === 'settings'}
          <div class="demo-content"><p class="demo-description">{t('demo.settingsHint')}</p><label class="demo-setting"><span>{t('demo.fontSize')}<output>{fontSize} px</output></span><input type="range" min="12" max="18" step="1" bind:value={fontSize} /></label><div class="demo-reset-setting"><p>{t('demo.resetHint')}</p><button type="button" class="demo-button" on:click={reset}><Icon name="reset" size={16} />{t('demo.reset')}</button></div></div>
        {/if}
      </div>
    </div>
  {/if}
  <div class="demo-caption"><p class="sl-image-caption">{t(ready ? 'demo.caption' : 'demo.noScript')}</p><button type="button" disabled={!ready} on:click={reset}><Icon name="reset" size={13} />{t('demo.reset')}</button></div>
</section>

<style>
  .demo-shell { --d-bg: #e9e9ed; --d-surface: #f2f2f5; --d-card: #fff; --d-selected: #fff; --d-ink: #242529; --d-muted: #6b6b76; --d-line: #dcdce2; --d-accent: #087f77; --d-terminal: #fcfcfd; --d-terminal-ink: #30363e; --d-prompt: #087b83; --d-error: #ac3545; display: grid; grid-template-columns: 18% minmax(0, 1fr); height: 600px; border: 1px solid var(--d-line); border-radius: 13px; padding: 7px; color: var(--d-ink); background: var(--d-bg); box-shadow: 0 20px 55px -35px var(--sl-shadow); overflow: hidden; font-size: 13px; }
  :global(:root[data-theme='dark']) .demo-shell { --d-bg: #171719; --d-surface: #1e1e21; --d-card: #26262a; --d-selected: #2a2a2e; --d-ink: #e5e5ea; --d-muted: #a2a2ad; --d-line: #303035; --d-accent: #31c9bb; --d-terminal: #0e1116; --d-terminal-ink: #d6dce3; --d-prompt: #74d5df; --d-error: #f09a9f; }
  .demo-fallback { height: 600px; overflow: hidden; border-radius: 13px; border: 1px solid var(--sl-line); background: #171719; }
  .demo-fallback img { width: 100%; height: 100%; object-fit: cover; object-position: top left; }
  .demo-shell button, .demo-shell input { font: inherit; }
  .demo-shell button { transition: background-color .15s, color .15s; }
  .demo-shell button:focus-visible, .demo-shell input:focus-visible, .demo-shell textarea:focus-visible { outline: 2px solid var(--d-accent); outline-offset: -2px; }
  .demo-shell button:disabled { opacity: .4; cursor: default; }
  .demo-shell :global(svg) { flex-shrink: 0; }
  .demo-sidebar { display: flex; flex-direction: column; min-width: 0; padding: 0 10px 4px 3px; }
  .demo-window-controls { height: 43px; display: flex; align-items: center; padding-left: 13px; gap: 7px; flex-shrink: 0; }
  .demo-window-controls i { width: 10px; height: 10px; border-radius: 50%; background: #ff6059; }
  .demo-window-controls i:nth-child(2) { background: #ffbd2e; }.demo-window-controls i:nth-child(3) { background: #28c840; }
  .demo-sidebar nav { display: flex; flex-direction: column; gap: 6px; flex: 1; padding-top: 9px; }
  .demo-sidebar button { display: flex; align-items: center; gap: 11px; width: 100%; min-height: 42px; padding: 9px 12px; border: 0; border-radius: 8px; background: transparent; color: var(--d-muted); text-align: left; font-weight: 600; }
  .demo-sidebar button.current { background: var(--d-selected); color: var(--d-ink); }
  .demo-sidebar button.current :global(svg) { color: var(--d-accent); }
  .demo-sidebar button.settings { margin-top: auto; }
  .demo-sidebar small { margin-left: auto; font-size: 10px; color: var(--d-accent); }
  .demo-workspace { min-width: 0; min-height: 0; background: var(--d-surface); border-radius: 10px; overflow: hidden; display: flex; flex-direction: column; }
  .demo-session-bar { display: flex; align-items: center; gap: 5px; min-height: 43px; padding: 5px 8px; }
  .demo-tabs { display: flex; gap: 4px; min-width: 0; overflow-x: auto; scrollbar-width: thin; }
  .demo-tab { display: flex; align-items: center; flex-shrink: 0; border-radius: 7px; color: var(--d-muted); transition: background-color .15s, color .15s; }
  .demo-tab.active { background: var(--d-selected); color: var(--d-ink); }
  .demo-tab > button { display: flex; align-items: center; gap: 8px; height: 32px; border: 0; border-radius: 7px; background: transparent; white-space: nowrap; padding: 0 3px 0 10px; font-weight: 600; }
  .demo-tab.active .demo-tab-select > :global(svg) { color: var(--d-accent); }
  .demo-tab .demo-close-tab { justify-content: center; padding: 0; margin: 0 4px 0 3px; width: 24px; min-width: 24px; height: 24px; color: var(--d-muted); border-radius: 5px; }
  .demo-icon { width: 32px; height: 32px; display: inline-flex; justify-content: center; align-items: center; padding: 0; border: 0; border-radius: 6px; background: transparent; color: var(--d-muted); flex-shrink: 0; }
  .demo-add { border: 1px solid var(--d-line); }
  .demo-session-tools { display: flex; margin-left: auto; }
  .demo-terminal { background: var(--d-terminal); color: var(--d-terminal-ink); display: flex; flex-direction: column; min-height: 0; flex: 1; }
  .demo-terminal-scroll { flex: 1; overflow: auto; padding: 17px 15px; overscroll-behavior: contain; scrollbar-width: thin; }
  .demo-output, .demo-command-form { font: var(--demo-font-size)/1.65 var(--font-mono); overflow-wrap: anywhere; }
  .demo-entry { margin-bottom: 19px; }
  .demo-entry pre { font: inherit; white-space: pre-wrap; margin: 0; overflow-wrap: anywhere; }
  .demo-entry pre.error { color: var(--d-error); }
  .demo-prompt { color: var(--d-prompt); font-weight: 600; }
  .demo-cwd { color: var(--d-muted); }.demo-dollar { padding: 0 4px; }
  .demo-command-form { display: flex; flex-wrap: wrap; align-items: center; gap: 0 7px; }
  .demo-command-form label { cursor: text; }
  .demo-command-input { display: flex; flex: 1; min-width: 90px; align-items: center; }
  .demo-command-input input { min-width: 0; width: 100%; background: transparent; color: var(--d-terminal-ink); caret-color: var(--d-accent); border: 0; border-radius: 0; padding: 2px 0; }
  .demo-shell .demo-command-input input:focus { outline: none; box-shadow: none; }
  .demo-command-form:focus-within .demo-dollar { color: var(--d-accent); }
  .demo-command-input .demo-icon { opacity: .65; }
  .demo-suggestions { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; padding: 12px 15px; border-top: 1px solid var(--d-line); color: var(--d-muted); font-size: 11px; }
  .demo-suggestions > span { margin-right: 4px; }
  .demo-suggestions button { font: 11px var(--font-mono); background: transparent; color: var(--d-terminal-ink); border: 1px solid var(--d-line); border-radius: 5px; padding: 6px 8px; }
  .demo-heading { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 15px 15px 9px; min-height: 60px; }
  .demo-heading h3 { display: flex; align-items: center; gap: 9px; font-size: 16px; font-weight: 600; margin: 0; white-space: nowrap; }
  .demo-heading h3 small { display: grid; place-items: center; background: var(--d-bg); border-radius: 20px; padding: 2px 7px; color: var(--d-muted); font-size: 11px; }
  .demo-search { display: flex; align-items: center; gap: 8px; background: var(--d-bg); color: var(--d-muted); border: 1px solid var(--d-line); border-radius: 20px; padding: 7px 11px; width: 245px; max-width: 60%; }
  .demo-search input { width: 100%; min-width: 0; border: 0; outline: none; background: transparent; color: var(--d-ink); font-size: 12px; }
  .demo-search input::placeholder { color: var(--d-muted); opacity: 1; }
  .demo-content { padding: 13px 15px; overflow: auto; min-height: 0; flex: 1; overscroll-behavior: contain; }
  .demo-host-list { display: flex; flex-direction: column; gap: 9px; }
  .demo-host { display: flex; align-items: center; gap: 12px; padding: 12px; border-radius: 10px; background: var(--d-card); }
  .demo-host > :global(svg) { color: var(--d-muted); }
  .demo-host-copy { display: flex; flex-wrap: wrap; gap: 3px 9px; align-items: baseline; flex: 1; min-width: 0; }
  .demo-host-copy strong { font-weight: 600; }.demo-host-copy span { font-size: 11px; color: var(--d-muted); overflow-wrap: anywhere; }
  .demo-host-actions { display: flex; gap: 7px; }
  .demo-button { display: inline-flex; align-items: center; justify-content: center; gap: 7px; min-height: 34px; border: 0; border-radius: 7px; padding: 7px 11px; background: var(--d-bg); color: var(--d-ink); font-weight: 600; font-size: 12px; }
  .demo-button.primary { background: var(--d-accent); color: var(--d-card); }
  :global(:root[data-theme='dark']) .demo-button.primary { color: #102521; }
  .demo-file-toolbar { display: flex; align-items: center; gap: 8px; padding: 12px 14px; }
  .demo-file-toolbar > code { font: 12px var(--font-mono); min-width: 0; overflow-wrap: anywhere; }
  .demo-file-toolbar .demo-search { margin-left: auto; width: 180px; }
  .demo-file-list { padding-top: 0; }
  .demo-file-row { display: flex; align-items: center; gap: 14px; min-height: 60px; border-radius: 7px; }
  .demo-file-open { display: flex; align-items: center; gap: 12px; flex: 1; min-width: 0; text-align: left; border: 0; background: transparent; border-radius: 6px; padding: 9px 5px; }
  .demo-file-open > :global(svg) { color: var(--d-muted); }
  .demo-file-open span { min-width: 0; }.demo-file-open strong { display: block; font-weight: 600; overflow-wrap: anywhere; }.demo-file-open small { display: block; margin-top: 4px; color: var(--d-muted); font-size: 11px; }
  .demo-file-size { color: var(--d-muted); white-space: nowrap; font-size: 11px; }.demo-permissions { color: var(--d-muted); font: 11px var(--font-mono); }.demo-folder-spacer { width: 32px; }
  .demo-file-preview { min-height: 0; flex: 1; display: flex; flex-direction: column; background: var(--d-terminal); }
  .demo-file-preview header { display: flex; align-items: center; gap: 9px; padding: 8px 15px; border-bottom: 1px solid var(--d-line); }.demo-file-preview header button { margin-left: auto; }
  .demo-file-preview textarea { flex: 1; min-height: 0; width: 100%; padding: 18px; margin: 0; border: 0; border-radius: 0; resize: none; background: transparent; font: 13px/1.8 var(--font-mono); color: var(--d-terminal-ink); white-space: pre-wrap; overflow-wrap: anywhere; overflow: auto; }
  .demo-transfer-feedback { min-height: 32px; padding: 7px 16px; font-size: 11px; color: var(--d-accent); overflow-wrap: anywhere; }
  .demo-empty { display: flex; flex-direction: column; align-items: center; text-align: center; gap: 15px; color: var(--d-muted); padding: 65px 20px; }.demo-empty h4 { color: var(--d-ink); margin: 0; font-size: 15px; font-weight: 600; }.demo-empty p { max-width: 300px; margin: 0; font-size: 12px; line-height: 1.8; }
  .demo-transfer-row { display: flex; align-items: center; gap: 12px; padding: 14px 0; border-bottom: 1px solid var(--d-line); }.demo-transfer-row > :global(svg) { color: var(--d-accent); }.demo-transfer-row > div { flex: 1; min-width: 0; }.demo-transfer-row strong, .demo-transfer-row span, .demo-transfer-row small { display: block; }.demo-transfer-row span, .demo-transfer-row small { font-size: 11px; color: var(--d-muted); margin-top: 5px; overflow-wrap: anywhere; }.demo-transfer-row .demo-complete { color: var(--d-accent); margin: 0; }
  .demo-text-button { border: 0; padding: 5px; background: transparent; color: var(--d-accent); font-size: 12px; }
  .demo-description { color: var(--d-muted); font-size: 12px; line-height: 1.8; margin: 0 0 20px; }
  .demo-snippet { display: flex; align-items: center; text-align: left; gap: 14px; width: 100%; border: 0; border-radius: 9px; background: var(--d-card); padding: 17px 14px; margin-bottom: 10px; }.demo-snippet > span { min-width: 0; flex: 1; }.demo-snippet strong { display: block; font-weight: 600; }.demo-snippet code { display: block; color: var(--d-muted); font: 12px/1.6 var(--font-mono); margin-top: 6px; overflow-wrap: anywhere; }.demo-snippet > :global(svg) { color: var(--d-accent); }
  .demo-setting { display: block; max-width: 380px; padding: 20px; border-radius: 9px; background: var(--d-card); }.demo-setting span { display: flex; justify-content: space-between; gap: 15px; }.demo-setting output { color: var(--d-muted); font: 12px var(--font-mono); }.demo-setting input { width: 100%; accent-color: var(--d-accent); margin-top: 20px; }
  .demo-reset-setting { margin-top: 30px; }.demo-reset-setting p { color: var(--d-muted); font-size: 12px; line-height: 1.8; margin-bottom: 15px; }
  .demo-caption { display: flex; justify-content: space-between; align-items: baseline; gap: 16px; }.demo-caption button { display: flex; align-items: center; gap: 6px; flex-shrink: 0; background: transparent; border: 0; color: var(--sl-muted); padding: 10px 0; font-size: 11px; }
  @media (hover: hover) {
    .demo-shell button:not(:disabled):not(.demo-tab-select):hover { background-color: color-mix(in srgb, var(--d-ink) 8%, transparent); }
    .demo-button.primary:hover { background: color-mix(in srgb, var(--d-accent) 85%, var(--d-ink)); }
    .demo-tab:hover { background-color: color-mix(in srgb, var(--d-ink) 5%, transparent); color: var(--d-ink); }
    .demo-tab.active:hover { background-color: color-mix(in srgb, var(--d-ink) 4%, var(--d-selected)); }
    .demo-close-tab:hover { color: var(--d-ink); }
  }
  @media (max-width: 950px) { .demo-shell { grid-template-columns: 155px minmax(0, 1fr); height: 550px; }.demo-fallback { height: 550px; }.demo-host-copy { flex-direction: column; }.demo-host-actions .demo-button { padding: 8px; }.demo-host-actions .demo-button span { display: none; } }
  @media (max-width: 700px) { .demo-shell { grid-template-columns: 58px minmax(0, 1fr); }.demo-sidebar { padding: 0 7px 3px 0; }.demo-sidebar button { justify-content: center; padding: 8px; position: relative; }.demo-sidebar button > span { display: none; }.demo-sidebar small { position: absolute; right: 2px; top: 2px; }.demo-window-controls { gap: 4px; padding-left: 5px; }.demo-window-controls i { width: 8px; height: 8px; }.demo-permissions { display: none; } }
  @media (max-width: 560px) {
    .demo-shell { display: flex; flex-direction: column; height: 520px; padding: 5px; border-radius: 10px; }.demo-fallback { height: 520px; }
    .demo-sidebar { display: contents; }.demo-window-controls { height: 25px; padding-left: 9px; order: 0; gap: 5px; }.demo-sidebar nav { order: 2; flex: 0 0 auto; flex-direction: row; justify-content: space-between; gap: 2px; padding: 5px 0 0; }.demo-sidebar button { flex: 1; gap: 4px; flex-direction: column; min-height: 49px; padding: 5px 2px; }.demo-sidebar button > span { display: block; font-size: 9px; font-weight: 500; }.demo-sidebar button.settings { margin-top: 0; }.demo-sidebar small { right: 7px; }
    .demo-workspace { flex: 1; order: 1; border-radius: 7px; }.demo-session-bar { min-height: 43px; padding: 5px; gap: 4px; }.demo-tab > button { font-size: 11px; gap: 5px; padding-left: 7px; }.demo-session-tools { display: none; }.demo-add { width: 30px; }.demo-tabs { flex: 1; }
    .demo-terminal-scroll { padding: 12px 11px; }.demo-output, .demo-command-form { font-size: max(12px, calc(var(--demo-font-size) - 1px)); line-height: 1.6; }.demo-cwd { display: none; }.demo-command-form label { flex-basis: 100%; }.demo-command-form label .demo-dollar { display: none; }.demo-command-input input { font-size: 16px; min-height: 36px; }.demo-command-input::before { content: '%'; margin-right: 8px; color: var(--d-muted); }.demo-command-input:focus-within::before { color: var(--d-accent); }.demo-command-input .demo-icon { width: 36px; height: 36px; border: 1px solid var(--d-line); }
    .demo-suggestions { padding: 9px; gap: 5px; }.demo-suggestions > span { flex-basis: 100%; font-size: 10px; }.demo-suggestions button { font-size: 10px; padding: 7px 6px; }
    .demo-heading { flex-wrap: wrap; min-height: 50px; padding: 12px 10px 7px; gap: 10px; }.demo-heading h3 { font-size: 15px; }.demo-search { max-width: 100%; width: 100%; padding: 6px 10px; }.demo-search input { font-size: 16px; }.demo-content { padding: 10px; }.demo-host { padding: 11px 9px; gap: 8px; }.demo-host > :global(svg) { display: none; }.demo-host-copy strong { font-size: 12px; }.demo-host-copy span { font-size: 10px; }.demo-host-actions { gap: 4px; }.demo-host-actions .demo-button { width: 34px; min-height: 36px; }.demo-host-list { gap: 8px; }
    .demo-file-toolbar { padding: 7px 10px; gap: 5px; flex-wrap: wrap; }.demo-file-toolbar .demo-search { max-width: 100%; width: 100%; flex-basis: 100%; margin-top: 3px; }.demo-file-row { min-height: 54px; gap: 8px; }.demo-file-open { gap: 8px; }.demo-file-open strong { font-size: 12px; }.demo-file-open small { font-size: 10px; }.demo-file-size { font-size: 10px; }.demo-file-row .demo-icon { width: 36px; height: 40px; }.demo-file-list { padding-top: 0; }.demo-file-preview textarea { font-size: 16px; padding: 12px; }
    .demo-empty { padding: 40px 10px; }.demo-transfer-row { flex-wrap: wrap; }.demo-transfer-row .demo-complete { margin-left: 32px; flex-basis: 100%; }.demo-snippet { padding: 13px 10px; gap: 10px; }.demo-snippet code { font-size: 11px; }.demo-setting { padding: 15px; }
    .demo-caption { align-items: start; gap: 10px; }.demo-caption button { font-size: 10px; padding-top: 14px; }.demo-caption button :global(svg) { display: none; }
  }
  @media (prefers-reduced-motion: reduce) { .demo-shell button, .demo-tab { transition: none; } }
</style>
