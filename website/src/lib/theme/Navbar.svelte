<script lang="ts">
  import { SearchDialog } from 'svedocs/theme';
  import { resolveLocalizedHref } from 'svedocs/theme/headless';
  import type { SvedocsNavbarProps } from 'svedocs/theme/types';
  import Icon from '../Icon.svelte';
  import ThemeToggle from './ThemeToggle.svelte';
  import Sidebar from './Sidebar.svelte';
  import LocaleSwitcher from './LocaleSwitcher.svelte';
  export let context: SvedocsNavbarProps['context'];
  export let mobileTree: NonNullable<SvedocsNavbarProps['mobileTree']> = [];
  export let mobileCurrentPath = '';
  export let mobileMenuId = 'sl-navigation';
  export let mobileMenuOpen = false;
  export let onToggleMobileMenu: () => void = () => undefined;
  export let onCloseMobileMenu: () => void = () => undefined;
  $: nav = context.config.theme.nav;
</script>
<header class="sl-header" class:sl-menu-open={mobileMenuOpen}>
  <a class="sl-brand" href={resolveLocalizedHref('/', context)} aria-label={context.t('site.home')}><img src="/app-icon.png" width="32" height="32" alt="" /><span>Serlink<span class="sl-brand-period">.</span></span></a>
  <nav class="sl-desktop-nav" aria-label={context.t('nav.primary')}>
    {#each nav as item}<a class:sl-active={context.activeNavHref === resolveLocalizedHref(item.href, context)} href={resolveLocalizedHref(item.href, context)}>{item.labelKey ? context.t(item.labelKey) : item.label}</a>{/each}
  </nav>
  <div class="sl-header-tools">
    <SearchDialog records={context.search} loadRecords={context.loadSearch} scope={context.searchScope} provider={context.config.search.provider} buildMode={context.config.build.mode} {context} />
    <LocaleSwitcher {context} />
    <ThemeToggle {context} />
  </div>
  <a class="sl-header-cta" href={resolveLocalizedHref('/download', context)}>{context.t('site.get')}<Icon name="arrow" size={15} /></a>
  <button class="sl-menu-toggle sl-icon-button" type="button" on:click={onToggleMobileMenu} aria-label={mobileMenuOpen ? context.t('nav.mobile.close') : context.t('nav.mobile.open')} aria-controls={mobileMenuId} aria-expanded={mobileMenuOpen}><Icon name={mobileMenuOpen ? 'close' : 'menu'} /></button>
  {#if mobileMenuOpen}
    <div class="sl-mobile-nav" id={mobileMenuId}>
      <nav aria-label={context.t('nav.primary')}>{#each nav as item}<a href={resolveLocalizedHref(item.href, context)} on:click={onCloseMobileMenu}>{item.labelKey ? context.t(item.labelKey) : item.label}<Icon name="arrow" size={17} /></a>{/each}<a href={resolveLocalizedHref('/download', context)}>{context.t('site.get')}<Icon name="arrow" size={17} /></a></nav>
      {#if context.isDocsPage}<div class="sl-mobile-docs"><p>{context.t('site.docs')}</p><Sidebar items={mobileTree} currentPath={mobileCurrentPath} /></div>{/if}
    </div>
  {/if}
</header>
