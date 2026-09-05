#!/usr/bin/env node
'use strict';

/**
 * Tu dong dang nhap Admin va them hang loat de bai Luyen Viet AI tren
 * https://english-ai-app-9b33e.web.app tu du lieu trong
 * tools/output/bulk_writing_data.json.
 *
 * Ky thuat giong het tools/bulk_add_listening.js: kich hoat cay
 * semantics cua Flutter Web (canvas-rendered) de co cac node DOM
 * that, roi dung Playwright thao tac nhu nguoi dung.
 *
 * Cach chay:
 *   ADMIN_EMAIL=... ADMIN_PASSWORD=... node tools/bulk_add_writing.js
 */

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const APP_URL = 'https://english-ai-app-9b33e.web.app';

const ADMIN_EMAIL = process.env.ADMIN_EMAIL;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD;

if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
  console.error(
    'Thiếu ADMIN_EMAIL / ADMIN_PASSWORD trong biến môi trường.',
  );
  process.exit(1);
}

const DATA_PATH = path.join(__dirname, 'output', 'bulk_writing_data.json');
const SCREENSHOT_DIR = path.join(__dirname, 'bulk_add_writing_screenshots');

function log(message) {
  console.log(`[${new Date().toISOString()}] ${message}`);
}

async function enableSemantics(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 20000 });
  await placeholder.dispatchEvent('click');
  await page.waitForTimeout(1000);
}

async function typeInto(page, locator, text) {
  await locator.click();
  await page.waitForTimeout(150);
  await page.keyboard.insertText(text);
  await page.waitForTimeout(150);
}

async function login(page) {
  log('Đang mở trang web và đăng nhập Admin...');

  await page.goto(APP_URL, { waitUntil: 'networkidle' });
  await page.waitForTimeout(2000);
  await enableSemantics(page);

  await typeInto(page, page.locator('input[aria-label="Email"]'), ADMIN_EMAIL);
  await typeInto(
    page,
    page.locator('input[aria-label="Mật khẩu"]'),
    ADMIN_PASSWORD,
  );

  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await page.waitForTimeout(4000);

  const bodyText = await page.evaluate(() => document.body.innerText);

  if (!bodyText.includes('Quản trị hệ thống')) {
    throw new Error(
      'Đăng nhập không thành công hoặc tài khoản không có quyền Admin.',
    );
  }

  log('Đăng nhập Admin thành công.');
}

async function openWritingManagement(page) {
  // The dashboard bunches cards into a scrollable area - cards below
  // the fold are not mounted into the semantics tree until scrolled
  // into view (same lazy-mount behaviour as any long ListView/
  // GridView). Scroll down with the mouse positioned over the
  // content until the target card's text appears.
  await page.mouse.move(640, 450);

  let found = false;

  for (let i = 0; i < 10; i++) {
    const bodyText = await page.evaluate(() => document.body.innerText);

    if (bodyText.includes('Quản lý Luyện Viết AI')) {
      found = true;
      break;
    }

    await page.mouse.wheel(0, 500);
    await page.waitForTimeout(500);
  }

  if (!found) {
    throw new Error(
      'Không tìm thấy thẻ "Quản lý Luyện Viết AI" trên Admin Dashboard sau khi cuộn.',
    );
  }

  await page
    .getByText('Quản lý Luyện Viết AI', { exact: false })
    .first()
    .click();
  await page.waitForTimeout(2000);
}

async function countEntries(page) {
  return page.getByRole('button', { name: 'Xóa', exact: true }).count();
}

async function addOneTask(page, task, index, total) {
  log(`[${index + 1}/${total}] Bắt đầu thêm: "${task.title}"`);

  const countBefore = await countEntries(page);

  await page.getByText('Thêm đề bài', { exact: false }).first().click();
  await page.waitForTimeout(1000);

  await typeInto(page, page.locator('input[aria-label="Tiêu đề"]'), task.title);

  // Loai de mac dinh la "task1" - dung cho ca 6 de nay, khong can
  // dong vao dropdown "Loai de".

  await typeInto(
    page,
    page.locator('textarea[aria-label="Đề bài (promptText)"]'),
    task.promptText,
  );
  await typeInto(
    page,
    page.locator('input[aria-label="Link ảnh biểu đồ (nếu có)"]'),
    task.imageUrl,
  );
  await typeInto(
    page,
    page.locator(
      'input[aria-label="Dạng biểu đồ (line/bar/map/process/pie)"]',
    ),
    task.chartType,
  );

  const minWordsField = page.locator('input[aria-label="Số từ tối thiểu"]');
  await minWordsField.click();
  await page.keyboard.press('Control+A');
  await page.keyboard.insertText(String(task.minWords));
  await page.waitForTimeout(150);

  await typeInto(
    page,
    page.locator('input[aria-label="Nguồn đề (nếu có)"]'),
    task.source,
  );

  const timeLimitField = page.locator(
    'input[aria-label="Thời gian làm bài (phút)"]',
  );
  await timeLimitField.click();
  await page.keyboard.press('Control+A');
  await page.keyboard.insertText(String(task.timeLimitMinutes));
  await page.waitForTimeout(150);

  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, `${index + 1}_before_submit.png`),
    fullPage: true,
  });

  await page.getByRole('button', { name: 'Thêm đề bài', exact: true }).click();
  await page.waitForTimeout(2500);

  const bodyText = await page.evaluate(() => document.body.innerText);
  const countAfter = await countEntries(page);

  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, `${index + 1}_after_submit.png`),
    fullPage: true,
  });

  if (bodyText.includes('Không thể lưu đề bài')) {
    throw new Error(`Lưu thất bại - Firestore báo lỗi: ${bodyText.slice(0, 300)}`);
  }

  // Luu y: giong nhu bulk_add_listening.js, so nut "Xoa" dang mount
  // co the KHONG tang dung 1 khi danh sach dai (ListView lazy-mount
  // cac the ngoai vung nhin thay). Chi coi day la dau hieu tham
  // khao, khong phai bang chung loi that su.
  log(
    `[${index + 1}/${total}] Đã submit "${task.title}" ` +
      `(số nút Xóa đang mount: ${countBefore} -> ${countAfter}, ` +
      `có thể không phản ánh đúng tổng số do lazy-mount danh sách dài).`,
  );
}

async function main() {
  const tasks = JSON.parse(fs.readFileSync(DATA_PATH, 'utf8'));

  log(`Đọc được ${tasks.length} đề cần thêm từ ${DATA_PATH}`);

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });

  const results = { success: [], failed: [] };

  try {
    await login(page);
    await openWritingManagement(page);

    for (let i = 0; i < tasks.length; i++) {
      const task = tasks[i];

      try {
        await addOneTask(page, task, i, tasks.length);
        results.success.push(task);
      } catch (error) {
        log(`[${i + 1}/${tasks.length}] LỖI khi thêm "${task.title}": ${error.message}`);
        results.failed.push({ task, error: error.message });

        const cancelButton = page.getByRole('button', {
          name: 'Hủy',
          exact: true,
        });

        if (await cancelButton.count()) {
          await cancelButton.first().click();
          await page.waitForTimeout(800);
        }
      }
    }
  } finally {
    await browser.close();
  }

  console.log('\n========== KẾT QUẢ ==========');
  console.log(`Đã submit: ${results.success.length}/${tasks.length}`);

  for (const task of results.success) {
    console.log(`  ✔ ${task.title}`);
  }

  console.log(`Lỗi khi submit: ${results.failed.length}/${tasks.length}`);

  for (const item of results.failed) {
    console.log(`  ✘ ${item.task.title}: ${item.error}`);
  }

  if (results.failed.length > 0) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error('Lỗi không mong đợi:', error);
  process.exitCode = 1;
});
