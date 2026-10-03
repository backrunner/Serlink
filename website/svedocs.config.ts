import { defineConfig } from 'svedocs/config';
import { en, zh, ja } from './src/lib/messages.ts';
export default defineConfig({
  site: { name: 'Serlink', title: 'Serlink', description: 'SSH terminals, SFTP file transfers and encrypted credentials.', url: 'https://serlink.alkinum.com' },
  build: { mode: 'static' },
  theme: {
    defaultMode: 'system', readingStyle: 'plain',
    palette: { accent: '#087f70', neutral: 'slate' }, radius: '12px',
    fonts: { sans: '-apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Hiragino Sans", sans-serif', mono: '"SFMono-Regular", Menlo, Consolas, monospace' },
    brand: { label: 'Serlink', href: '/', logo: '/app-icon.png', mark: false },
    nav: [
      { label: 'Features', labelKey: 'site.features', href: '/#features' },
      { label: 'Documentation', labelKey: 'site.docs', href: '/docs' },
      { label: 'Support', labelKey: 'site.support', href: '/support' }
    ],
    footer: { text: 'Serlink', links: [
      { label: 'Privacy', labelKey: 'site.privacy', href: '/privacy' },
      { label: 'License', labelKey: 'site.licenses', href: '/licenses' },
      { label: 'Support', labelKey: 'site.support', href: '/support' },
      { label: 'GitHub', href: 'https://github.com/backrunner/Serlink', external: true }
    ] }
  },
  search: { provider: 'local', scope: 'current' }, ai: false,
  agent: { enabled: true, markdown: true, llms: true, negotiation: false },
  checks: { assets: true, translations: true },
  i18n: { defaultLocale: 'en', prefixDefaultLocale: false, locales: [
    { code: 'en', label: 'English', hreflang: 'en', ogLocale: 'en_US' },
    { code: 'zh', label: '简体中文', hreflang: 'zh-CN', ogLocale: 'zh_CN' },
    { code: 'ja', label: '日本語', hreflang: 'ja', ogLocale: 'ja_JP' }
  ], messages: { en, zh, ja } },
  seo: { sitemap: true, robots: true, ogImage: false, head: {
    meta: [{ property: 'og:image', content: 'https://serlink.alkinum.com/og.png' }, { name: 'twitter:card', content: 'summary_large_image' }]
  } },
  source: { editBaseUrl: 'https://github.com/backrunner/Serlink/edit/main/website' }
});
