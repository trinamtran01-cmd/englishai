#!/usr/bin/env node
'use strict';

/**
 * Tu dong dang nhap Admin va them hang loat bai luyen nghe & noi tren
 * https://english-ai-app-9b33e.web.app tu du lieu trong
 * tools/output/bulk_listening_data.json.
 *
 * Ung dung la Flutter Web (ve bang canvas, khong phai DOM thuong), nen
 * script kich hoat cay semantics (accessibility) cua Flutter de co cac
 * node DOM that (input/textarea/button) tuong ung voi tung widget, roi
 * dung Playwright de dien va bam nut nhu nguoi dung that.
 *
 * Cach chay:
 *   ADMIN_EMAIL=... ADMIN_PASSWORD=... node tools/bulk_add_listening.js
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

const DATA_PATH = path.join(__dirname, 'output', 'bulk_listening_data.json');
const SCREENSHOT_DIR = path.join(__dirname, 'bulk_add_screenshots');

const LEVEL_LABELS = {
  beginner: 'Cơ bản',
  intermediate: 'Trung cấp',
  advanced: 'Nâng cao',
};

function log(message) {
  console.log(`[${new Date().toISOString()}] ${message}`);
}

async function enableSemantics(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 20000 });
  await placeholder.dispatchEvent('click');
  await page.waitForTimeout(1000);
}

/** Dien text vao 1 o input/textarea cua Flutter web: click de focus
 * roi dung CDP Input.insertText (nhanh, khong go tung ky tu) thay vi
 * `.fill()` - vi `.fill()` gan gia tri qua JS property nen mot so o
 * (da kiem chung: o Link video YouTube) khong duoc Flutter ghi nhan
 * cap nhat State ben trong. */
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

async function openListeningManagement(page) {
  await page
    .getByText('Quản lý luyện nghe & nói', { exact: false })
    .first()
    .click();
  await page.waitForTimeout(2000);
}

async function countEntries(page) {
  return page.getByRole('button', { name: 'Xóa', exact: true }).count();
}

async function addOneVideo(page, video, index, total) {
  log(
    `[${index + 1}/${total}] Bắt đầu thêm: "${video.title}" (${video.videoId})`,
  );

  const countBefore = await countEntries(page);

  await page.getByText('Thêm bài luyện nghe', { exact: false }).first().click();
  await page.waitForTimeout(1000);

  await typeInto(page, page.locator('input[aria-label="Tiêu đề"]'), video.title);
  await typeInto(
    page,
    page.locator('input[aria-label="Link hoặc ID video YouTube"]'),
    video.videoId,
  );
  await typeInto(
    page,
    page.locator('textarea[aria-label="Mô tả"]'),
    video.description,
  );

  const levelLabel = LEVEL_LABELS[video.level];

  if (!levelLabel) {
    throw new Error(`Level không hợp lệ: ${video.level}`);
  }

  if (levelLabel !== 'Cơ bản') {
    // "Cơ bản" là gia tri mac dinh cua dropdown, chi can bam khi
    // muon doi sang muc khac.
    await page.getByRole('button', { name: /Mức độ/ }).click();
    await page.waitForTimeout(500);
    await page.getByRole('menuitem', { name: levelLabel }).click();
    await page.waitForTimeout(400);
  }

  await typeInto(
    page,
    page.locator('textarea[aria-label="Câu gợi ý luyện nói"]'),
    video.speakingPrompt,
  );
  await typeInto(
    page,
    page.locator('textarea[aria-label="Transcript (dán cả đoạn văn bản)"]'),
    video.transcript,
  );

  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, `${video.videoId}_before_submit.png`),
    fullPage: true,
  });

  await page
    .getByRole('button', { name: 'Thêm bài luyện nghe', exact: true })
    .click();
  await page.waitForTimeout(2500);

  const bodyText = await page.evaluate(() => document.body.innerText);
  const countAfter = await countEntries(page);

  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, `${video.videoId}_after_submit.png`),
    fullPage: true,
  });

  if (bodyText.includes('Không thể lưu bài luyện nghe')) {
    throw new Error(`Lưu thất bại - Firestore báo lỗi: ${bodyText.slice(0, 300)}`);
  }

  if (countAfter !== countBefore + 1) {
    throw new Error(
      `Số lượng bài luyện nghe không tăng đúng 1 sau khi submit ` +
        `(trước: ${countBefore}, sau: ${countAfter}). Có thể submit thất bại.`,
    );
  }

  log(
    `[${index + 1}/${total}] ĐÃ THÊM THÀNH CÔNG: "${video.title}" ` +
      `(số bài luyện nghe: ${countBefore} -> ${countAfter})`,
  );
}

async function main() {
  const videos = JSON.parse(fs.readFileSync(DATA_PATH, 'utf8'));

  log(`Đọc được ${videos.length} video cần thêm từ ${DATA_PATH}`);

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });

  const results = {
    success: [],
    failed: [],
  };

  try {
    await login(page);
    await openListeningManagement(page);

    for (let i = 0; i < videos.length; i++) {
      const video = videos[i];

      try {
        await addOneVideo(page, video, i, videos.length);
        results.success.push(video);
      } catch (error) {
        log(
          `[${i + 1}/${videos.length}] LỖI khi thêm "${video.title}" ` +
            `(${video.videoId}): ${error.message}`,
        );
        results.failed.push({ video, error: error.message });

        // Neu dialog form con dang mo do loi, thu dong lai truoc khi
        // sang video tiep theo de khong lam hong trang thai trang.
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
  console.log(`Thành công: ${results.success.length}/${videos.length}`);

  for (const video of results.success) {
    console.log(`  ✔ ${video.title} (${video.videoId})`);
  }

  console.log(`Thất bại: ${results.failed.length}/${videos.length}`);

  for (const item of results.failed) {
    console.log(`  ✘ ${item.video.title} (${item.video.videoId}): ${item.error}`);
  }

  if (results.failed.length > 0) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error('Lỗi không mong đợi:', error);
  process.exitCode = 1;
});
