import { readFileSync } from 'node:fs';
import { test, expect } from '@playwright/test';

// Use the build's route inventory so newly published translations/pages join the audit.
const sitemap = readFileSync(new URL('../build/sitemap.xml', import.meta.url), 'utf8');
const paths = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => new URL(match[1]).pathname);
const environment = process.env.SERLINK_TEST_BASE_URL ? 'live' : 'local';

for (const path of paths) {
  for (const theme of ['light', 'dark'] as const) {
    test(`${theme} ${path}: page layout and prose stay readable`, async ({ page }, info) => {
      const errors: string[] = [];
      page.on('pageerror', (error) => errors.push(error.message));
      await page.emulateMedia({ colorScheme: theme });
      if (info.project.name === 'mobile') await page.setViewportSize({ width: 320, height: 844 });
      expect((await page.goto(path))?.status()).toBe(200);
      await expect(page.locator('html')).toHaveAttribute('data-theme', theme);
      await expect(page.locator('main')).toHaveCount(1);
      await expect(page.locator('h1')).toBeVisible();
      await expect(page.locator('.sl-header')).toBeVisible();

      const layout = await page.evaluate(() => {
        const header = document.querySelector('.sl-header')!.getBoundingClientRect();
        const heading = document.querySelector('h1')!.getBoundingClientRect();
        const prose = document.querySelector<HTMLElement>('.sd-prose');
        const broken: string[] = [];
        const visible = (element: Element) => element.getBoundingClientRect().width > 0;
        for (const element of document.querySelectorAll('main :is(h1, h2, h3, p, table, .sd-code)')) {
          if (!visible(element) || element.closest('.demo-shell')) continue;
          const rect = element.getBoundingClientRect();
          if (rect.left < -1 || rect.right > innerWidth + 1) broken.push(`${element.tagName}: ${element.textContent?.slice(0, 60)}`);
        }
        for (const list of prose?.querySelectorAll('ul, ol') ?? []) {
          if (getComputedStyle(list).listStyleType === 'none') broken.push('missing list markers');
        }
        for (const cell of prose?.querySelectorAll('th, td') ?? []) {
          if (parseFloat(getComputedStyle(cell).borderTopWidth) === 0) broken.push('missing table cell border');
        }
        for (const block of prose?.querySelectorAll('.sd-code') ?? []) {
          const lines = [...block.querySelectorAll('.line')];
          for (let index = 1; index < lines.length; index++) {
            const previous = lines[index - 1].getBoundingClientRect();
            if (lines[index].getBoundingClientRect().top < previous.bottom - 1) broken.push('collapsed code lines');
          }
          const tokenColors = [...block.querySelectorAll('.sd-line-content span[style]')].map((token) => getComputedStyle(token).color);
          if (block.getAttribute('data-language') === 'json' && new Set(tokenColors).size < 2) broken.push('missing syntax colors');
        }
        return {
          overflow: document.documentElement.scrollWidth > innerWidth,
          headingBelowHeader: heading.top >= header.bottom,
          broken,
          brokenImages: [...document.images].filter((image) => visible(image) && image.complete && image.naturalWidth === 0).map((image) => image.src),
        };
      });
      expect(layout.overflow, path).toBe(false);
      expect(layout.headingBelowHeader, path).toBe(true);
      expect(layout.broken, path).toEqual([]);
      expect(layout.brokenImages, path).toEqual([]);

      const slug = path.replace(/^\/+|\/+$/g, '').replaceAll('/', '-') || 'home';
      await page.screenshot({ path: `.svedocs/style-review/${environment}/${info.project.name}-${theme}-${slug}.png`, fullPage: true });
      // Check each document's anchor after scrolling, including the fixed header offset.
      if (path.startsWith('/docs')) {
        const heading = page.locator('.sd-prose h2[id]').first();
        await expect(heading).toBeVisible();
        const id = await heading.getAttribute('id');
        await page.evaluate((id) => { location.hash = id!; }, id);
        await expect.poll(() => heading.evaluate((element) => element.getBoundingClientRect().top)).toBeGreaterThan(90);
      }
      expect(errors, path).toEqual([]);
    });
  }
}
