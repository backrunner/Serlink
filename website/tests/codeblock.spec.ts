import { readFileSync } from 'node:fs';
import { test, expect } from '@playwright/test';

const locales = [
  { code: 'en', docs: '/docs', pages: '', copy: 'Copy code', copied: 'Copied' },
  { code: 'zh', docs: '/docs/zh', pages: '/zh', copy: '复制代码', copied: '已复制' },
  { code: 'ja', docs: '/docs/ja', pages: '/ja', copy: 'コードをコピー', copied: 'コピー済み' },
];

function sourceCode(path: string): string {
  const markdown = readFileSync(new URL(`../content/${path}`, import.meta.url), 'utf8');
  return markdown.match(/```\w+\n([\s\S]*?)\n```/)![1];
}

for (const locale of locales) {
  for (const theme of ['light', 'dark'] as const) {
    test(`${locale.code} ${theme}: code lines, highlighting, scrolling and exact keyboard copy`, async ({ page, context }, info) => {
      const errors: string[] = [];
      page.on('pageerror', (error) => errors.push(error.message));
      await context.grantPermissions(['clipboard-read', 'clipboard-write']);
      await page.emulateMedia({ colorScheme: theme });
      await page.goto(`${locale.docs}/agents/`);
      await expect(page.locator('html')).toHaveAttribute('data-theme', theme);

      const block = page.locator('.sd-code');
      const expected = sourceCode(`docs/${locale.code}/agents.md`);
      await expect(block.locator('.sd-line-content')).toHaveText(expected.split('\n'));
      const layout = await block.evaluate((element) => {
        const lines = [...element.querySelectorAll<HTMLElement>('.line')];
        const code = element.querySelector<HTMLElement>('code')!;
        const tokens = [...element.querySelectorAll<HTMLElement>('.sd-line-content span[style]')];
        const luminance = (color: string) => {
          const channels = color.match(/[\d.]+/g)!.slice(0, 3).map(Number).map((value) => {
            const v = value / 255;
            return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
          });
          return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
        };
        const background = luminance(getComputedStyle(element).backgroundColor);
        return {
          lines: lines.map((line) => ({ y: line.getBoundingClientRect().y, height: line.getBoundingClientRect().height })),
          colors: [...new Set(tokens.map((token) => getComputedStyle(token).color))],
          contrast: tokens.map((token) => {
            const foreground = luminance(getComputedStyle(token).color);
            return (Math.max(foreground, background) + 0.05) / (Math.min(foreground, background) + 0.05);
          }),
          whiteSpace: getComputedStyle(code).whiteSpace,
          clientWidth: code.clientWidth,
          scrollWidth: code.scrollWidth,
          pageOverflow: document.documentElement.scrollWidth > innerWidth,
        };
      });
      for (let index = 1; index < layout.lines.length; index++) {
        expect(layout.lines[index].y).toBeGreaterThanOrEqual(layout.lines[index - 1].y + layout.lines[index - 1].height - 1);
      }
      expect(layout.colors.length).toBeGreaterThan(1);
      expect(Math.min(...layout.contrast)).toBeGreaterThanOrEqual(4.5);
      expect(layout.whiteSpace).toBe('pre');
      expect(layout.pageOverflow).toBe(false);
      if (info.project.name === 'mobile') {
        expect(layout.scrollWidth).toBeGreaterThan(layout.clientWidth);
        const headerX = await block.locator('.sd-code-header').evaluate((element) => element.getBoundingClientRect().x);
        await block.locator('code').evaluate((element) => { element.scrollLeft = element.scrollWidth; });
        expect(await block.locator('code').evaluate((element) => element.scrollLeft)).toBeGreaterThan(0);
        expect(await block.locator('.sd-code-header').evaluate((element) => element.getBoundingClientRect().x)).toBe(headerX);
        await block.locator('code').evaluate((element) => { element.scrollLeft = 0; });
      }
      await block.scrollIntoViewIfNeeded();
      await block.screenshot({ path: `test-results/codeblock-${locale.code}-${theme}-${info.project.name}.png` });

      const copy = block.getByRole('button', { name: locale.copy, exact: true });
      await copy.focus();
      await copy.press('Enter');
      await expect.poll(() => page.evaluate(() => navigator.clipboard.readText())).toBe(expected);
      await expect(block.locator('.sd-code-copy')).toHaveAttribute('data-state', 'copied');
      await expect(block.locator('.sd-code-copy')).toHaveAttribute('aria-label', locale.copied);
      await expect(block.locator('.sd-code-copy')).toHaveAttribute('aria-label', locale.copy);

      // Ordinary pages use a separate shell/action; verify their multi-line shell commands too.
      await page.goto(`${locale.pages}/download/`);
      await page.locator('.sd-code-copy').click();
      await expect.poll(() => page.evaluate(() => navigator.clipboard.readText())).toBe(sourceCode(`pages/${locale.code}/download.md`));
      expect(errors).toEqual([]);
    });
  }

  test(`${locale.code}: code remains readable without JavaScript`, async ({ browser }, info) => {
    const context = await browser.newContext({ javaScriptEnabled: false, viewport: info.project.use.viewport });
    const page = await context.newPage();
    await page.goto(`http://127.0.0.1:4189${locale.docs}/agents/`);
    const lines = page.locator('.sd-code .line');
    await expect(lines).toHaveCount(9);
    const first = await lines.nth(0).boundingBox();
    const second = await lines.nth(1).boundingBox();
    expect(second!.y).toBeGreaterThanOrEqual(first!.y + first!.height - 1);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    await context.close();
  });
}
