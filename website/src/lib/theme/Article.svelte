<script lang="ts">
  import { fallbackTranslate, resolveLocalizedHref } from 'svedocs/theme/headless';
  import type { SvedocsArticleProps } from 'svedocs/theme/types';
  import Icon from '../Icon.svelte';
  import { codeCopy } from '../codeCopy';
  export let page: SvedocsArticleProps['page'];
  export let content: SvedocsArticleProps['content'] = undefined;
  export let context: SvedocsArticleProps['context'] = undefined;
  $: t = context?.t ?? fallbackTranslate;
</script>
<article class="sl-article" use:codeCopy={t}>
  <header><a class="sl-eyebrow sl-document-kicker" href={context ? resolveLocalizedHref('/docs', context) : '/docs'}><Icon name="terminal" size={15} />{t('site.docs')}</a><h1>{page.title}</h1><p class="sl-lede">{page.description}</p></header>
  <div class="sd-prose">{#if content}<svelte:component this={content} />{:else}{@html page.html}{/if}</div>
  <div class="sl-article-help"><span>{t('docs.help')}</span><a href={context ? resolveLocalizedHref('/support', context) : '/support'}>{t('site.support')}<Icon name="arrow" size={16} /></a></div>
</article>
