<script lang="ts">
  import { onMount, tick } from 'svelte';
  import { page } from '$app/stores';
  import pageLoaders from 'virtual:svedocs/page-loaders';
  import type { SvedocsPage } from 'svedocs/core';
  import type { SvedocsThemeContext } from 'svedocs/theme/types';
  export let context: SvedocsThemeContext;
  let open = false;
  let pending = false;
  let menuRequest = 0;
  let translations = new Map<string, SvedocsPage>();
  let root: HTMLDivElement;
  let trigger: HTMLButtonElement;
  $: locales = context.config.i18n.locales;
  $: current = locales.find((locale) => locale.code === context.localeCode);
  $: label = current?.label ?? context.localeCode;
  $: short = [...label].length <= 3 ? label : context.localeCode.toUpperCase();

  function localeHref(code: string): string {
    const source = context.page;
    const indexPage = context.pages.find((candidate) => candidate.scopePath === (source?.scopePath ?? '/') && candidate.locale === code);
    const target = indexPage ? translations.get(indexPage.id) ?? indexPage : undefined;
    const locale = locales.find((candidate) => candidate.code === code);
    const path = target?.routePath ?? (locale?.path || '/');
    let hash = $page.url.hash;
    if (hash && source && target && target.headings.length > 0) {
      try {
        const index = source.headings.findIndex((heading) => heading.id === decodeURIComponent(hash.slice(1)));
        // All three translations keep the same section structure; map translated slugs.
        if (index >= 0) {
          const equivalent = target.headings[index];
          hash = source.headings.length === target.headings.length && equivalent?.depth === source.headings[index].depth
            ? `#${encodeURIComponent(equivalent.id)}` : '';
        }
      } catch { hash = ''; }
    }
    return `${path}${$page.url.search}${hash}`;
  }
  function close(restoreFocus = false) { menuRequest++; pending = false; open = false; if (restoreFocus) trigger.focus(); }
  async function show() {
    const request = ++menuRequest;
    pending = true;
    // The lightweight page index omits headings. Load only corresponding translations
    // when a deep link needs a translated section slug.
    if ($page.url.hash && context.page) {
      const candidates = context.pages.filter((candidate) => candidate.scopePath === context.page?.scopePath);
      await Promise.all(candidates.map(async (candidate) => {
        if (translations.has(candidate.id)) return;
        try {
          const loaded = await pageLoaders[candidate.id]?.();
          if (loaded?.default) translations.set(candidate.id, loaded.default);
        } catch { /* Navigation remains available if translation preloading fails. */ }
      }));
      translations = new Map(translations);
    }
    if (request !== menuRequest) return;
    pending = false;
    open = true;
    await tick();
    root.querySelector<HTMLAnchorElement>('[aria-checked="true"]')?.focus();
  }
  function key(event: KeyboardEvent) {
    if (event.key === 'Escape') { event.preventDefault(); close(true); return; }
    const links = Array.from(root.querySelectorAll<HTMLAnchorElement>('[role="menuitemradio"]'));
    const index = links.indexOf(document.activeElement as HTMLAnchorElement);
    let next: number;
    if (event.key === 'ArrowDown') next = (index + 1) % links.length;
    else if (event.key === 'ArrowUp') next = (index - 1 + links.length) % links.length;
    else if (event.key === 'Home') next = 0;
    else if (event.key === 'End') next = links.length - 1;
    else if (event.key === 'Tab') { close(); return; }
    else return;
    event.preventDefault(); links[next]?.focus();
  }
  onMount(() => {
    const outside = (event: PointerEvent) => { if (!root.contains(event.target as Node)) close(); };
    document.addEventListener('pointerdown', outside);
    return () => { menuRequest++; document.removeEventListener('pointerdown', outside); };
  });
</script>
<div bind:this={root} class="sd-scope-switcher" role="group" aria-label={context.t('scope.group')}>
  <div class="sd-scope-menu" class:sd-open={open}>
    <button bind:this={trigger} class="sd-scope-trigger" type="button" aria-label={context.t('scope.locale')} aria-haspopup="menu" aria-expanded={open} aria-busy={pending} on:click={() => open ? close() : show()} on:keydown={(event) => { if (event.key === 'ArrowDown') { event.preventDefault(); void show(); } }}>
      <span class="sd-scope-label-full">{label}</span><span class="sd-scope-label-short" aria-hidden="true">{short}</span>
    </button>
    {#if open}<div class="sd-scope-options" role="menu" tabindex="-1" aria-label={context.t('scope.localeOptions')} on:keydown={key}>
      {#each locales as locale}<a href={localeHref(locale.code)} role="menuitemradio" aria-checked={locale.code === context.localeCode} aria-current={locale.code === context.localeCode ? 'page' : undefined} on:click={() => close()}>{locale.label}</a>{/each}
    </div>{/if}
  </div>
</div>
