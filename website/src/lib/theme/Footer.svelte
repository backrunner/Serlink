<script lang="ts">
  import { resolveLocalizedHref } from 'svedocs/theme/headless';
  import type { SvedocsFooterProps } from 'svedocs/theme/types';
  import Icon from '../Icon.svelte';
  export let context: SvedocsFooterProps['context'];
  $: footer = context.config.theme.footer;
</script>
<footer class="sl-footer">
  <div class="sl-footer-main"><a class="sl-brand" href={resolveLocalizedHref('/', context)}><img src="/app-icon.png" width="28" height="28" alt="" /><span>Serlink.</span></a><p>{context.t('footer.tagline')}</p><a class="sl-footer-top" href="#content">{context.t('site.backTop')}<Icon name="arrow" size={16} /></a></div>
  <div class="sl-footer-bottom"><span>© {new Date().getUTCFullYear()} Alkinum</span><nav aria-label={context.t('nav.footer')}>{#if footer !== false}{#each footer.links as link}<a href={resolveLocalizedHref(link.href, context)}>{link.labelKey ? context.t(link.labelKey) : link.label}</a>{/each}{/if}</nav></div>
</footer>
