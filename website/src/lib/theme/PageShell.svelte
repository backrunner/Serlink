<script lang="ts">
  import { fallbackTranslate } from 'svedocs/theme/headless';
  import { codeCopy } from '../codeCopy';
  import type { SvedocsPageShellProps } from 'svedocs/theme/types';
  export let page: SvedocsPageShellProps['page'] = undefined;
  export let variant: SvedocsPageShellProps['variant'] = 'page';
  export let title = '';
  export let description = '';
  export let kicker = '';
  export let content: SvedocsPageShellProps['content'] = undefined;
  export let html = '';
  export let status: number | undefined = undefined;
  export let path = '';
  export let actions: NonNullable<SvedocsPageShellProps['actions']> = [];
  export let context: SvedocsPageShellProps['context'] = undefined;
  $: t = context?.t ?? fallbackTranslate;
  $: pageKicker = kicker && kicker !== t('article.kind.page') ? kicker : '';
</script>
<main lang={context?.languageTag} id="content" class="sl-page" class:sl-error={variant === 'error'}>
  <header><!-- Show a useful status or an explicit custom label, without a generic page badge. -->
    {#if variant === 'error'}<p class="sl-label">{status ?? 404}</p>{:else if pageKicker}<p class="sl-label">{pageKicker}</p>{/if}<h1>{title || page?.title || ''}</h1><p class="sl-lede">{description || page?.description || ''}</p>{#if variant === 'error' && path}<code>{path}</code>{/if}</header>
  {#if variant === 'error'}<div class="sl-actions">{#each actions as action}<a class="sl-button" class:sl-primary={action.primary} href={action.href}>{action.label}</a>{/each}</div>{:else}<article class="sd-prose" use:codeCopy={t}>{#if content}<svelte:component this={content} />{:else}{@html html || page?.html || ''}{/if}</article>{/if}
</main>
