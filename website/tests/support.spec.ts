import { test, expect, type Page } from '@playwright/test';

// Load through the real external-script path so CSP failures remain visible.
async function verification(page: Page) {
  await page.route('https://challenges.cloudflare.com/**', route => route.fulfill({
    contentType: 'application/javascript',
    body: `window.turnstile = {
      render(element, options) { queueMicrotask(() => options.callback('mock-verified-token')); return 'mock-widget'; },
      reset() {}, remove() {}
    };`
  }));
}

for (const locale of ['en', 'zh', 'ja']) test(`support loads verification and submits ${locale} only once`, async ({ page }) => {
  await verification(page);
  const requests: Record<string, string>[] = [];
  await page.route('**/api/support', async route => {
    requests.push(route.request().postDataJSON());
    await route.fulfill({ status: 201, json: { ticketId: 'support-reference' } });
  });
  const response = await page.goto(locale === 'en' ? '/support/' : `/${locale}/support/`);
  expect(response?.ok()).toBe(true);
  await expect(page.locator('.support-send')).toBeEnabled();
  await page.locator('input[name="email"]').fill('reader@example.com');
  await page.locator('input[name="subject"]').fill('Directory question');
  await page.locator('textarea[name="content"]').fill('How do I manage my listing?');
  await page.locator('input[value="question"]').check();
  await page.locator('.support-send').click();
  await expect(page.locator('.support-success')).toContainText('support-reference');
  expect(requests).toHaveLength(1);
  expect(requests[0]).toMatchObject({ locale, topic: 'question', turnstileToken: 'mock-verified-token' });
  await expect(page.locator('a[href^="mailto:"]')).toHaveCount(0);
});

test('support preserves uncertain submissions without automatically retrying', async ({ page }) => {
  await verification(page);
  let requests = 0;
  await page.route('**/api/support', async route => {
    requests++;
    await route.fulfill({ status: 502, json: { error: 'uncertain' } });
  });
  await page.goto('/support/');
  await page.locator('input[name="email"]').fill('reader@example.com');
  await page.locator('input[name="subject"]').fill('My request');
  await page.locator('textarea[name="content"]').fill('Keep these steps available.');
  await page.locator('.support-send').click();
  await expect(page.getByRole('alert')).toBeVisible();
  await expect(page.locator('textarea')).toHaveValue('Keep these steps available.');
  await expect(page.locator('.support-send')).toBeDisabled();
  expect(requests).toBe(1);
});

test('support keeps failed verification recoverable at narrow widths', async ({ page }) => {
  await page.route('https://challenges.cloudflare.com/**', route => route.abort());
  for (const width of [320, 390, 768]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto('/support/');
    await expect(page.getByRole('button', { name: 'Retry verification' })).toBeVisible();
    await expect(page.locator('.support-send')).toBeDisabled();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  }
});
