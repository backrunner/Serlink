import { test, expect } from '@playwright/test';

const locales = [
  { code: 'en', prefix: '', headline: 'Your servers. One workspace.', vault: 'Vault & recovery', search: 'vault', lang: 'en' },
  { code: 'zh', prefix: '/zh', headline: '你的服务器。 一个工作空间。', vault: '保险库与恢复', search: '保险库', lang: 'zh-CN' },
  { code: 'ja', prefix: '/ja', headline: 'あなたのサーバー。 ひとつのワークスペース。', vault: 'ボールトと復旧', search: 'ボールト', lang: 'ja' },
];
for (const locale of locales) {
  test(`${locale.code}: homepage, gallery, navigation and contact`, async ({ page }, info) => {
    const errors: string[] = [];
    page.on('pageerror', (error) => errors.push(error.message));
    await page.goto(`${locale.prefix}/`);
    await expect(page.locator('main')).toHaveCount(1);
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('html')).toHaveAttribute('lang', locale.lang);
    await expect(page.locator('link[rel="canonical"]')).toHaveAttribute('href', `https://serlink.alkinum.com${locale.prefix}/`);
    await expect(page.locator('link[rel="alternate"][hreflang]')).toHaveCount(4);
    const image = page.locator('.sl-product-image img');
    for (const [index, file] of ['01-hosts', '02-terminal', '03-sftp'].entries()) {
      await page.locator('.sl-preview-switcher button').nth(index).click();
      await expect(image).toHaveAttribute('src', `/screenshots/${locale.code}/${file}.jpg`);
      await expect.poll(() => image.evaluate((img: HTMLImageElement) => img.complete && img.naturalWidth > 0)).toBeTruthy();
      await expect(page.locator('.sl-preview-switcher button').nth(index)).toHaveAttribute('aria-pressed', 'true');
    }
    await page.locator('.sl-preview-switcher button').nth(1).click();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBeTruthy();
    await page.screenshot({ path: `test-results/home-${locale.code}-${info.project.name}.png`, fullPage: true });
    if (info.project.name === 'mobile') {
      await page.locator('.sl-menu-toggle').click();
      await expect(page.locator('.sl-mobile-nav')).toBeVisible();
      await page.locator('.sl-mobile-nav a').filter({ hasText: locale.code === 'en' ? 'Documentation' : locale.code === 'zh' ? '使用文档' : 'ドキュメント' }).click();
    } else await page.locator('.sl-desktop-nav a').nth(1).click();
    await expect(page).toHaveURL(new RegExp(`/docs${locale.prefix}/?$`));
    await expect(page.locator('.sl-article')).toBeVisible();
    await expect(page.locator('main')).toHaveCount(1);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBeTruthy();
    await page.goto(`${locale.prefix}/support/`);
    await expect(page.locator('a[href^="mailto:support@serlink.alkinum.com"]')).toHaveCount(1);
    expect(errors).toEqual([]);
  });
  test(`${locale.code}: local scoped search and keyboard dismissal`, async ({ page }) => {
    const external: string[] = [];
    page.on('request', (request) => { if (!request.url().startsWith('http://127.0.0.1:4189')) external.push(request.url()); });
    await page.goto(`${locale.prefix}/`);
    await page.locator('.sd-search-trigger').click();
    const input = page.getByRole('combobox');
    await input.fill(locale.search);
    await expect(page.getByRole('option').first()).toBeVisible();
    const hrefs = await page.getByRole('option').evaluateAll((items) => items.map((item) => item.getAttribute('href')));
    expect(hrefs.every((href) => locale.prefix ? href?.startsWith(`${locale.prefix}/`) || href?.startsWith(`/docs${locale.prefix}`) : !/^\/(?:docs\/)?(?:zh|ja)(?:\/|$)/.test(href ?? ''))).toBeTruthy();
    await input.press('Escape');
    await expect(page.getByRole('dialog')).not.toBeVisible();
    await expect(page.locator('.sd-search-trigger')).toBeFocused();
    await page.locator('.sd-search-trigger').click();
    await input.fill(locale.search);
    await expect(page.getByRole('option').first()).toContainText(locale.search, { ignoreCase: true });
    await input.press('Enter');
    await expect(page).toHaveURL(/docs|privacy/);
    await expect(page.getByRole('dialog')).not.toBeVisible();
    expect(external).toEqual([]);
  });
}

test('theme follows system, persists and switches without resetting routes', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.goto('/');
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  const theme = page.getByTestId('theme-toggle');
  await theme.click();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
  await page.reload();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
  await theme.click();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  await page.goto('/docs/vault/');
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  await theme.click();
  await expect(theme).toHaveAttribute('aria-label', 'Theme: System');
  await page.emulateMedia({ colorScheme: 'light' });
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
});

test('language menu preserves query, translates fragment and supports keyboard', async ({ page }) => {
  await page.goto('/docs/vault/?from=guide#recovery-and-backups');
  await page.locator('.sd-scope-trigger').click();
  await page.getByRole('menuitemradio', { name: '简体中文' }).click();
  await expect(page.locator('h1')).toHaveText('保险库与恢复');
  expect(new URL(page.url()).search).toBe('?from=guide');
  expect(decodeURIComponent(new URL(page.url()).hash)).toBe('#恢复与备份');
  await page.locator('.sd-scope-trigger').press('ArrowDown');
  await expect(page.getByRole('menu')).toBeVisible();
  await page.getByRole('menuitemradio', { name: '简体中文' }).press('Escape');
  await expect(page.getByRole('menu')).not.toBeVisible();
  await expect(page.locator('.sd-scope-trigger')).toBeFocused();
});

test('copy tools work in both docs and ordinary pages', async ({ page, context }) => {
  await context.grantPermissions(['clipboard-read', 'clipboard-write']);
  await page.goto('/docs/');
  await page.locator('.sd-code-copy').first().click();
  await expect.poll(() => page.evaluate(() => navigator.clipboard.readText())).toBe('pwd');
  await page.goto('/download/');
  await expect(page.locator('main')).toContainText('no public installer or App Store listing');
  await page.locator('.sd-code-copy').first().click();
  await expect.poll(() => page.evaluate(() => navigator.clipboard.readText())).toContain('git clone https://github.com/backrunner/Serlink.git');
});

test('404 remains usable and static discovery files use the official domain', async ({ page, request }) => {
  const missing = await page.goto('/ja/missing-page/');
  expect(missing?.status()).toBe(404);
  await expect(page.locator('main')).toHaveCount(1);
  await expect(page.locator('h1')).toHaveText('この先にはページがありません。');
  await expect(page.locator('main a').first()).toHaveAttribute('href', '/ja');
  const sitemap = await request.get('/sitemap.xml');
  const urls = [...(await sitemap.text()).matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => new URL(match[1]).pathname);
  expect(urls).toHaveLength(39);
  for (const path of urls) { expect((await request.get(path)).status(), path).toBe(200); }
  for (const path of ['/sitemap.xml', '/robots.txt', '/llms.txt', '/llms-full.txt', '/docs/vault/index.md']) {
    const response = await request.get(path);
    expect(response.ok(), path).toBeTruthy();
    expect(await response.text(), path).toContain(path === '/docs/vault/index.md' ? 'Recovery and backups' : 'serlink.alkinum.com');
  }
});

test('narrow viewports do not hide header actions or overflow', async ({ page }) => {
  for (const width of [320, 768, 1024]) {
    await page.setViewportSize({ width, height: 844 });
    for (const path of ['/', '/ja/', '/docs/zh/agents/', '/download/', '/ja/support/']) {
      expect((await page.goto(path))?.status(), path).toBe(200);
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `${width} ${path}`).toBeTruthy();
      await expect(page.locator('.sd-search-trigger')).toBeVisible();
      await expect(page.locator('.sd-scope-trigger')).toBeVisible();
      await expect(page.getByTestId('theme-toggle')).toBeVisible();
    }
  }
});
