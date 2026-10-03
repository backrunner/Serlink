<script lang="ts">
  import type { SvedocsThemeContext } from 'svedocs/theme/types';
  import { resolveLocalizedHref } from 'svedocs/theme/headless';
  import Icon from './Icon.svelte';
  export let context: SvedocsThemeContext;
  let active = 1;
  const views = [
    { file: '01-hosts', icon: 'hosts', key: 'hosts' },
    { file: '02-terminal', icon: 'terminal', key: 'terminal' },
    { file: '03-sftp', icon: 'folder', key: 'sftp' }
  ];
  const features = [
    { key: 'terminal', href: '/docs/terminal' },
    { key: 'sftp', href: '/docs/sftp' },
    { key: 'hosts', href: '/docs/hosts' }
  ];
  const guides = [
    { key: 'start', href: '/docs' },
    { key: 'vault', href: '/docs/vault' },
    { key: 'agents', href: '/docs/agents' }
  ];
  $: t = context.t;
  $: locale = ['en', 'zh', 'ja'].includes(context.localeCode) ? context.localeCode : 'en';
</script>
<div class="sl-landing">
  <section class="sl-hero" aria-labelledby="hero-title">
    <div class="sl-hero-heading">
      <h1 id="hero-title">{t('hero.line1')}<br />{t('hero.line2')}</h1>
    </div>
    <div class="sl-hero-copy">
      <p>{t('hero.description')}</p>
      <div class="sl-actions">
        <a class="sl-button sl-primary" href={resolveLocalizedHref('/download', context)}>{t('site.get')}</a>
        <a class="sl-button sl-secondary" href={resolveLocalizedHref('/docs', context)}>{t('hero.guide')}</a>
      </div>
      <a class="sl-availability" href={resolveLocalizedHref('/download', context)}>{t('hero.availability')}</a>
    </div>
  </section>

  <section class="sl-showcase" aria-label={t('preview.label')}>
    <div class="sl-showcase-bar">
      <span class="sl-label">{t('preview.label')}</span>
      <div class="sl-preview-switcher" role="group" aria-label={t('preview.switch')}>
        {#each views as view, i}
          <button type="button" aria-pressed={active === i} class:sl-selected={active === i} on:click={() => active = i}>
            <Icon name={view.icon} size={16} /><span>{t(`preview.${view.key}`)}</span>
          </button>
        {/each}
      </div>
    </div>
    <div class="sl-product-image">
      <img src={`/screenshots/${locale}/${views[active].file}.jpg`} width="2560" height="1600" alt={t(`preview.${views[active].key}.alt`)} fetchpriority="high" />
    </div>
    <p class="sl-image-caption">{t('preview.caption')}</p>
  </section>

  <section id="features" class="sl-section" aria-labelledby="features-title">
    <div class="sl-section-heading"><h2 id="features-title">{t('features.title')}</h2></div>
    <div class="sl-feature-grid">
      {#each features as feature}
        <article>
          <h3>{t(`feature.${feature.key}.title`)}</h3>
          <p>{t(`feature.${feature.key}.body`)}</p>
          <a class="sl-text-link" href={resolveLocalizedHref(feature.href, context)}>{t(`feature.${feature.key}.link`)}</a>
        </article>
      {/each}
    </div>
  </section>

  <section id="privacy" class="sl-private" aria-labelledby="private-title">
    <div class="sl-private-copy">
      <h2 id="private-title">{t('privacy.title')}</h2>
      <p>{t('privacy.description')}</p>
      <a class="sl-text-link" href={resolveLocalizedHref('/docs/vault', context)}>{t('privacy.link')}</a>
    </div>
    <div class="sl-private-detail">
      <ul>{#each [1, 2, 3] as n}<li>{t(`privacy.point${n}`)}</li>{/each}</ul>
      <p>{t('privacy.note')}</p>
    </div>
  </section>

  <section class="sl-agent-row" aria-labelledby="agents-title">
    <div>
      <h2 id="agents-title">{t('agents.title')}</h2>
      <p>{t('agents.description')}</p>
    </div>
    <a class="sl-text-link" href={resolveLocalizedHref('/docs/agents', context)}>{t('agents.link')}</a>
  </section>

  <section class="sl-section sl-guides" aria-labelledby="guides-title">
    <div class="sl-section-heading">
      <h2 id="guides-title">{t('guides.title')}</h2>
      <a class="sl-text-link" href={resolveLocalizedHref('/docs', context)}>{t('guides.all')}</a>
    </div>
    <div class="sl-guide-list">
      {#each guides as guide}
        <a href={resolveLocalizedHref(guide.href, context)}>
          <div><h3>{t(`guide.${guide.key}.title`)}</h3><p>{t(`guide.${guide.key}.body`)}</p></div>
          <Icon name="arrow" size={18} />
        </a>
      {/each}
    </div>
  </section>

  <section class="sl-bottom-cta" aria-labelledby="release-title">
    <div><h2 id="release-title">{t('cta.title')}</h2><p>{t('cta.description')}</p></div>
    <a class="sl-button sl-primary" href={resolveLocalizedHref('/download', context)}>{t('cta.action')}</a>
  </section>
</div>
