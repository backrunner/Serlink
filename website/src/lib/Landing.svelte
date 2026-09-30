<script lang="ts">
  import type { SvedocsThemeContext } from 'svedocs/theme/types';
  import { resolveLocalizedHref } from 'svedocs/theme/headless';
  import Icon from './Icon.svelte';
  export let context: SvedocsThemeContext;
  let active = 1;
  const views = [{ file: '01-hosts', icon: 'hosts', key: 'hosts' }, { file: '02-terminal', icon: 'terminal', key: 'terminal' }, { file: '03-sftp', icon: 'folder', key: 'sftp' }];
  const features = [{ key: 'terminal', icon: 'terminal', href: '/docs/terminal' }, { key: 'sftp', icon: 'folder', href: '/docs/sftp' }, { key: 'hosts', icon: 'key', href: '/docs/hosts' }];
  const guides = [{ key: 'start', href: '/docs' }, { key: 'vault', href: '/docs/vault' }, { key: 'agents', href: '/docs/agents' }];
  $: t = context.t;
  $: locale = ['en', 'zh', 'ja'].includes(context.localeCode) ? context.localeCode : 'en';
</script>
<div class="sl-landing">
  <section class="sl-hero" aria-labelledby="hero-title">
    <div class="sl-hero-heading"><p class="sl-eyebrow"><span class="sl-pulse" aria-hidden="true"></span>{t('hero.eyebrow')}</p><h1 id="hero-title">{t('hero.line1')}<br /><span>{t('hero.line2')}</span></h1></div>
    <div class="sl-hero-copy"><p>{t('hero.description')}</p><div class="sl-actions"><a class="sl-button sl-primary" href={resolveLocalizedHref('/download', context)}>{t('site.get')}<Icon name="arrow" size={17} /></a><a class="sl-button sl-secondary" href={resolveLocalizedHref('/docs', context)}>{t('hero.guide')}</a></div><a class="sl-availability" href={resolveLocalizedHref('/download', context)}><span class="sl-status-dot" aria-hidden="true"></span>{t('hero.availability')}</a></div>
  </section>

  <section class="sl-showcase" aria-label={t('preview.label')}>
    <div class="sl-showcase-bar"><span class="sl-eyebrow">{t('preview.label')}</span><div class="sl-preview-switcher" role="group" aria-label={t('preview.switch')}>
      {#each views as view, i}<button type="button" aria-pressed={active === i} class:sl-selected={active === i} on:click={() => active = i}><Icon name={view.icon} size={16} /><span>{t(`preview.${view.key}`)}</span></button>{/each}
    </div></div>
    <div class="sl-product-image"><img src={`/screenshots/${locale}/${views[active].file}.jpg`} width="2560" height="1600" alt={t(`preview.${views[active].key}.alt`)} fetchpriority="high" /></div>
    <div class="sl-image-caption"><span>{t('preview.caption')}</span><span>macOS / Serlink</span></div>
  </section>

  <div class="sl-capabilities" aria-label={t('features.label')}><span><Icon name="terminal" size={17} />SSH</span><span><Icon name="folder" size={17} />SFTP</span><span><Icon name="lock" size={17} />{t('features.vault')}</span><a href={resolveLocalizedHref('/licenses', context)}><Icon name="code" size={17} />{t('features.open')}</a></div>

  <section id="features" class="sl-section" aria-labelledby="features-title"><div class="sl-section-heading"><div><p class="sl-eyebrow">01 / {t('features.eyebrow')}</p><h2 id="features-title">{t('features.title')}</h2></div><p>{t('features.description')}</p></div>
    <div class="sl-feature-grid">{#each features as feature, i}<article><div class="sl-feature-number"><Icon name={feature.icon} size={25} /><span>0{i + 1}</span></div><h3>{t(`feature.${feature.key}.title`)}</h3><p>{t(`feature.${feature.key}.body`)}</p><a class="sl-text-link" href={resolveLocalizedHref(feature.href, context)}>{t(`feature.${feature.key}.link`)}<Icon name="arrow" size={16} /></a></article>{/each}</div>
  </section>

  <section id="privacy" class="sl-private sl-section" aria-labelledby="private-title"><div class="sl-private-copy"><p class="sl-eyebrow">02 / {t('privacy.eyebrow')}</p><h2 id="private-title">{t('privacy.title')}</h2><p>{t('privacy.description')}</p><a class="sl-text-link" href={resolveLocalizedHref('/docs/vault', context)}>{t('privacy.link')}<Icon name="arrow" size={17} /></a></div>
    <div class="sl-private-detail"><div class="sl-encryption-diagram"><div><Icon name="hosts" size={23} /><span>{t('privacy.local')}</span></div><span class="sl-diagram-line" aria-hidden="true"></span><div class="sl-diagram-lock"><Icon name="lock" size={28} /><span>{t('privacy.encrypted')}</span></div><span class="sl-diagram-line" aria-hidden="true"></span><div><Icon name="cloud" size={23} /><span>{t('privacy.destination')}</span></div></div><ul>{#each [1, 2, 3] as n}<li><Icon name="check" size={17} />{t(`privacy.point${n}`)}</li>{/each}</ul><p>{t('privacy.note')}</p></div>
  </section>

  <section class="sl-agent-row" aria-labelledby="agents-title"><div class="sl-agent-icon"><Icon name="code" size={28} /></div><div><p class="sl-eyebrow">MCP / {t('agents.eyebrow')}</p><h2 id="agents-title">{t('agents.title')}</h2><p>{t('agents.description')}</p></div><a class="sl-text-link" href={resolveLocalizedHref('/docs/agents', context)}>{t('agents.link')}<Icon name="arrow" size={17} /></a></section>

  <section class="sl-section sl-guides" aria-labelledby="guides-title"><div class="sl-section-heading"><div><p class="sl-eyebrow">03 / {t('guides.eyebrow')}</p><h2 id="guides-title">{t('guides.title')}</h2></div><a class="sl-text-link" href={resolveLocalizedHref('/docs', context)}>{t('guides.all')}<Icon name="arrow" size={17} /></a></div>
    <div class="sl-guide-list">{#each guides as guide, i}<a href={resolveLocalizedHref(guide.href, context)}><span class="sl-guide-index">0{i + 1}</span><div><h3>{t(`guide.${guide.key}.title`)}</h3><p>{t(`guide.${guide.key}.body`)}</p></div><Icon name="arrow" size={21} /></a>{/each}</div>
  </section>
  <section class="sl-bottom-cta"><div><p class="sl-eyebrow">{t('cta.eyebrow')}</p><h2>{t('cta.title')}</h2></div><a class="sl-button sl-primary" href={resolveLocalizedHref('/download', context)}>{t('cta.action')}<Icon name="arrow" size={18} /></a></section>
</div>
