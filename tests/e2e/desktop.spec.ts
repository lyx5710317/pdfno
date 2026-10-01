import { test, expect, _electron as electron } from '@playwright/test';
import { mkdtemp, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
test('desktop: selection, isolated drafts, mock cancel/failure, save/restart and native bridge', async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'pdfno-desktop-'));
  const launch = () =>
    electron.launch({
      args: ['.', `--user-data-dir=${directory}`],
      timeout: 15000,
    });
  let app = await launch();
  try {
    let page = await app.firstWindow();
    await page.setViewportSize({ width: 1024, height: 768 });
    await expect(
      page.getByRole('heading', { name: '在原文里，留下理解。' }),
    ).toBeVisible();
    await page.getByRole('button', { name: 'JA · 少しずつ、読む' }).click();
    await expect(page.getByLabel('阅读导航')).toHaveCount(0);
    await page
      .getByRole('button', { name: '选择段落 ja-1', exact: true })
      .click();
    await expect(page.locator('.source-card blockquote')).toHaveText(
      '本を読みます。毎日、少しずつ学びます。',
    );
    await page.getByLabel('我的笔记').fill('my persistent note');
    await page.getByRole('button', { name: '日英语法', exact: true }).click();
    await page.getByLabel('我的笔记').fill('grammar draft');
    await page.getByRole('button', { name: '选文翻译', exact: true }).click();
    await expect(page.getByLabel('我的笔记')).toHaveValue('my persistent note');
    await page.getByLabel('测试情境').selectOption('hold');
    await page.getByRole('button', { name: '运行 mock', exact: true }).click();
    await expect(page.locator('.task-status')).toContainText('正在接收');
    await page
      .getByRole('button', { name: 'EN · A window into words' })
      .click();
    await expect(page.locator('.task-status')).toHaveCount(0);
    await page.getByRole('button', { name: 'JA · 少しずつ、読む' }).click();
    await page.getByRole('button', { name: '停止', exact: true }).click();
    await expect(page.locator('.task-status')).toContainText('已取消');
    await page.getByLabel('测试情境').selectOption('rate-limit');
    await page.getByRole('button', { name: '运行 mock', exact: true }).click();
    await expect(page.locator('.task-status')).toContainText('失败');
    await page
      .getByRole('button', { name: '保存当前选文笔记', exact: true })
      .click();
    await expect(page.locator('.save-state')).toContainText('本地已保存');
    await page.getByRole('button', { name: '打开设置', exact: true }).click();
    await page.getByRole('button', { name: '查询原生能力' }).click();
    await expect(
      page.getByText('macOS bridge 0.1.0 · Keychain 未集成 · iCloud 未启用'),
    ).toBeVisible();
    await app.close();
    app = await launch();
    page = await app.firstWindow();
    await page.getByRole('button', { name: 'JA · 少しずつ、読む' }).click();
    await page.getByRole('button', { name: '笔记 1', exact: true }).click();
    await expect(page.locator('.navigation')).toContainText(
      'my persistent note',
    );
    await page.screenshot({ path: 'test-results/desktop-workspace.png' });
    await page.setViewportSize({ width: 760, height: 800 });
    await page
      .getByRole('button', { name: '选择段落 ja-1', exact: true })
      .click();
    await expect(page.getByLabel('学习侧栏')).toBeVisible();
    await expect(page.getByLabel('阅读画布')).toBeVisible();
  } finally {
    await app.close();
    await rm(directory, { recursive: true, force: true });
  }
});
