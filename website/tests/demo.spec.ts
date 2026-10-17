import { test, expect } from '@playwright/test';
import { demoEn, demoZh, demoJa } from '../src/lib/demo/messages';

for (const [locale, copy] of Object.entries({ en: demoEn, zh: demoZh, ja: demoJa })) {
  test(`${locale}: commands, independent sessions, files and sample transfers`, async ({ page }, info) => {
    const errors: string[] = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(locale === 'en' ? '/' : `/${locale}/`);
    const demo = page.locator('.demo-shell');
    await expect(demo).toBeVisible();
    const network: string[] = [];
    page.on('request', request => network.push(request.url()));
    const command = page.getByRole('textbox', { name: copy['demo.command'], exact: true });
    const output = page.getByRole('log');
    await command.fill('pw');
    await command.press('Tab');
    await expect(command).toHaveValue('pwd');
    await command.press('Tab');
    await expect(page.getByRole('button', { name: copy['demo.run'], exact: true })).toBeFocused();
    await command.press('Enter');
    await expect(output.locator('.demo-entry').last()).toContainText('/srv/app');
    await command.fill('cd config');
    await command.press('Enter');
    await command.fill('cat nginx.conf');
    await command.press('Enter');
    await expect(output).toContainText('proxy_pass http://127.0.0.1:8080');
    await command.fill('draft');
    await command.press('ArrowUp');
    await expect(command).toHaveValue('cat nginx.conf');
    await command.press('ArrowDown');
    await expect(command).toHaveValue('draft');
    await command.fill('<script>alert(1)</script>');
    await command.press('Enter');
    await expect(output).toContainText(copy['demo.unsupported']);
    await expect(output.locator('script')).toHaveCount(0);

    await page.locator('.sl-preview-switcher button').nth(0).click();
    await demo.getByRole('textbox', { name: copy['demo.searchHosts'] }).fill('build');
    await expect(demo.locator('.demo-host')).toHaveCount(1);
    await demo.getByRole('button', { name: `${copy['demo.terminal']}: Build Runner`, exact: true }).click();
    await command.fill('hostname');
    await command.press('Enter');
    await expect(output.locator('.demo-entry').last()).toContainText('build.example.test');
    await demo.locator('.demo-tabs').getByRole('button', { name: 'Production Web', exact: true }).click();
    await expect(output).toContainText('proxy_pass');
    await command.fill('pwd');
    await command.press('Enter');
    await expect(output.locator('.demo-entry').last().locator('pre')).toHaveText('/srv/app/config');

    await page.locator('.sl-preview-switcher button').nth(2).click();
    await demo.locator('.demo-file-open').filter({ hasText: 'config' }).click();
    await expect(demo.locator('.demo-file-toolbar > code')).toHaveText('/srv/app/config');
    await demo.locator('.demo-file-open').filter({ hasText: 'nginx.conf' }).click();
    await expect(demo.getByRole('textbox', { name: 'nginx.conf' })).toHaveValue(/proxy_pass/);
    await page.keyboard.press('Escape');
    await expect(demo.locator('.demo-file-open').filter({ hasText: 'nginx.conf' })).toBeFocused();
    await demo.getByRole('button', { name: `${copy['demo.download']}: nginx.conf`, exact: true }).click();
    await expect(demo.getByRole('status')).toContainText(copy['demo.downloaded']);
    await demo.getByRole('navigation').getByRole('button', { name: new RegExp(copy['demo.transfers']) }).click();
    await expect(demo.locator('.demo-transfer-row')).toContainText('nginx.conf');
    await expect(demo.locator('.demo-transfer-row')).toContainText(copy['demo.complete']);
    await demo.getByRole('button', { name: copy['demo.clearTransfers'] }).click();
    await expect(demo).toContainText(copy['demo.emptyTransfers']);

    await demo.getByRole('navigation').getByRole('button', { name: copy['demo.snippets'], exact: true }).click();
    await demo.locator('.demo-snippet').filter({ hasText: copy['demo.logs'] }).click();
    await expect(output).toContainText('All health checks passed');
    await demo.getByRole('navigation').getByRole('button', { name: copy['demo.settings'], exact: true }).click();
    await demo.getByRole('slider').fill('18');
    await page.locator('.sl-preview-switcher button').nth(1).click();
    await expect(demo).toHaveAttribute('style', /18px/);
    await command.fill('clear');
    await command.press('Enter');
    await expect(output).toBeEmpty();
    await page.locator('.demo-caption button').click();
    await expect(demo.locator('.demo-tab')).toHaveCount(1);
    await expect(output).toContainText('uptime');
    await expect(demo).toHaveAttribute('style', /13px/);
    expect(network).toEqual([]);
    expect(errors).toEqual([]);
    await demo.screenshot({ path: `test-results/demo-${locale}-${info.project.name}-light.png` });
    // The existing theme control cycles system → light → dark.
    await page.getByTestId('theme-toggle').click();
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
    await page.getByTestId('theme-toggle').click();
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
    await demo.screenshot({ path: `test-results/demo-${locale}-${info.project.name}-dark.png` });
  });
}

test('all demo views fit at 320px and closed sessions can be reopened', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 720 });
  await page.goto('/ja/');
  const demo = page.locator('.demo-shell');
  await expect(demo).toBeVisible();
  for (const view of ['hosts', 'terminal', 'sftp', 'transfers', 'snippets', 'settings']) {
    if (view === 'sftp') await page.locator('.sl-preview-switcher button').nth(2).click();
    else {
      const index = ['hosts', 'terminal', 'transfers', 'snippets', 'settings'].indexOf(view);
      await demo.getByRole('navigation').getByRole('button').nth(index).click();
    }
    await expect(demo).toHaveAttribute('data-view', view);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), view).toBe(true);
    expect(await demo.locator('.demo-workspace').evaluate(el => el.scrollWidth <= el.clientWidth), view).toBe(true);
  }
  await page.locator('.demo-caption button').click();
  await demo.locator('.demo-close-tab').click();
  await expect(demo).toHaveAttribute('data-view', 'hosts');
  await page.locator('.sl-preview-switcher button').nth(1).click();
  await expect(demo.locator('.demo-tab')).toHaveCount(1);
  await expect(demo).toHaveAttribute('data-view', 'terminal');
});

test('without JavaScript, the localized app screenshot remains visible', async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  await page.goto('http://127.0.0.1:4189/zh/');
  await expect(page.locator('.demo-fallback img')).toBeVisible();
  await expect(page.locator('.demo-fallback img')).toHaveAttribute('src', '/screenshots/zh/02-terminal.jpg');
  await expect(page.getByText(demoZh['demo.noScript'])).toBeVisible();
  await context.close();
});
