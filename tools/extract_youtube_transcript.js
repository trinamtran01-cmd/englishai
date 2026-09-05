#!/usr/bin/env node
'use strict';

/**
 * Tải phụ đề (caption) tiếng Anh của 1 video YouTube bằng yt-dlp, làm
 * sạch (bỏ timestamp, cue index, ký hiệu người nói ">>", chú thích
 * [music]/[laughter]...) rồi xuất ra văn bản transcript thuần túy.
 *
 * Yêu cầu: yt-dlp đã cài (qua pip: `pip install yt-dlp`, hoặc binary
 * độc lập trong PATH tên `yt-dlp`).
 *
 * Cách chạy:
 *   node tools/extract_youtube_transcript.js <videoId>
 *
 * Output:
 *   tools/output/transcript_<videoId>_clean.txt
 */

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const OUTPUT_DIR = path.join(__dirname, 'output');
const CAPTIONS_DIR = path.join(__dirname, 'yt_captions');

// yt-dlp đôi khi bị YouTube trả 429 với client mặc định (web) - thử
// lần lượt các player client khác nhau cho tới khi tải được caption.
const PLAYER_CLIENT_ATTEMPTS = ['android', 'default', 'ios', 'tv'];

// Ưu tiên phụ đề người thật viết (en), sau đó tới auto-caption các
// biến thể ngôn ngữ khác nhau YouTube có thể gắn.
const SUB_LANGS = 'en,en-US,en-orig,en-GB';

/** Tìm lệnh gọi yt-dlp khả dụng trên máy: binary `yt-dlp` hoặc qua
 * Python `python -m yt_dlp`. */
function resolveYtDlpCommand() {
  const directAttempt = spawnSync('yt-dlp', ['--version'], {
    encoding: 'utf8',
  });

  if (!directAttempt.error && directAttempt.status === 0) {
    return { command: 'yt-dlp', baseArgs: [] };
  }

  const pythonAttempt = spawnSync(
    'python',
    ['-m', 'yt_dlp', '--version'],
    { encoding: 'utf8' },
  );

  if (!pythonAttempt.error && pythonAttempt.status === 0) {
    return { command: 'python', baseArgs: ['-m', 'yt_dlp'] };
  }

  throw new Error(
    'Không tìm thấy yt-dlp. Cài bằng "pip install yt-dlp" rồi thử lại.',
  );
}

/** Tải file caption .vtt cho videoId, thử lần lượt các player client
 * tới khi thành công. Trả về đường dẫn file .vtt đã tải, hoặc null
 * nếu không video nào tải được caption tiếng Anh. */
function downloadCaptionVtt(videoId) {
  const { command, baseArgs } = resolveYtDlpCommand();
  const videoUrl = `https://www.youtube.com/watch?v=${videoId}`;
  const outputTemplate = path.join(CAPTIONS_DIR, `${videoId}.%(ext)s`);

  fs.mkdirSync(CAPTIONS_DIR, { recursive: true });

  for (const playerClient of PLAYER_CLIENT_ATTEMPTS) {
    // Xóa file caption cũ (nếu có từ lần thử trước) để tránh đọc
    // nhầm kết quả của attempt trước đó khi attempt này fail.
    for (const staleFile of fs.readdirSync(CAPTIONS_DIR)) {
      if (staleFile.startsWith(`${videoId}.`)) {
        fs.unlinkSync(path.join(CAPTIONS_DIR, staleFile));
      }
    }

    const args = [
      ...baseArgs,
      '--skip-download',
      '--write-auto-sub',
      '--write-sub',
      '--sub-lang',
      SUB_LANGS,
      '--sub-format',
      'vtt',
      '-o',
      outputTemplate,
    ];

    if (playerClient !== 'default') {
      args.push(
        '--extractor-args',
        `youtube:player_client=${playerClient}`,
      );
    }

    args.push(videoUrl);

    console.log(
      `  [${videoId}] Thử tải caption với player_client=${playerClient}...`,
    );

    const result = spawnSync(command, args, { encoding: 'utf8' });
    const output = `${result.stdout || ''}${result.stderr || ''}`;

    const vttFiles = fs
      .readdirSync(CAPTIONS_DIR)
      .filter(
        (name) =>
          name.startsWith(`${videoId}.`) && name.endsWith('.vtt'),
      );

    if (vttFiles.length > 0) {
      // Ưu tiên file "en" thuần nếu có nhiều biến thể ngôn ngữ.
      const preferred =
        vttFiles.find((name) => name === `${videoId}.en.vtt`) ||
        vttFiles[0];

      return path.join(CAPTIONS_DIR, preferred);
    }

    if (/429|Too Many Requests/i.test(output)) {
      console.log(
        `  [${videoId}] Bị rate-limit (429) với player_client=${playerClient}, thử client khác...`,
      );
      continue;
    }

    if (/no subtitles/i.test(output) || /no automatic captions/i.test(output)) {
      console.log(
        `  [${videoId}] player_client=${playerClient}: video không có caption tiếng Anh.`,
      );
      continue;
    }
  }

  return null;
}

function decodeHtmlEntities(text) {
  return text
    .replace(/&amp;/g, '&')
    .replace(/&gt;/g, '>')
    .replace(/&lt;/g, '<')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

/** Làm sạch nội dung .vtt thô thành 1 đoạn văn bản transcript liền
 * mạch: bỏ timestamp/cue index, thẻ <c>, ký hiệu người nói ">>",
 * chú thích phi lời thoại kiểu [music]/[laughter], loại dòng trùng
 * lặp liên tiếp (một số caption YouTube dùng định dạng cuộn dòng,
 * lặp lại dòng trước đó ở cue kế tiếp). */
function cleanVttToTranscript(vttRaw) {
  const rawLines = vttRaw.split(/\r?\n/);

  const contentLines = [];
  let previousLine = null;

  for (const line of rawLines) {
    const trimmed = line.trim();

    if (!trimmed) {
      continue;
    }

    if (trimmed === 'WEBVTT') {
      continue;
    }

    if (/^Kind:/i.test(trimmed) || /^Language:/i.test(trimmed)) {
      continue;
    }

    if (trimmed.includes('-->')) {
      continue;
    }

    if (/^\d+$/.test(trimmed)) {
      continue;
    }

    // Bỏ thẻ timing từng-từ kiểu <00:00:01.234><c> ... </c>.
    const withoutTags = trimmed.replace(/<[^>]+>/g, '');

    const decoded = decodeHtmlEntities(withoutTags).trim();

    if (!decoded) {
      continue;
    }

    if (decoded === previousLine) {
      continue;
    }

    contentLines.push(decoded);
    previousLine = decoded;
  }

  let text = contentLines.join(' ');

  // Bỏ ký hiệu chuyển lượt người nói ">>" và chú thích phi lời thoại.
  text = text.replace(/>>+/g, ' ');
  text = text.replace(/\[[^\]]*\]/g, ' ');
  text = text.replace(/\s+/g, ' ').trim();

  return text;
}

function extractTranscriptForVideo(videoId) {
  const vttPath = downloadCaptionVtt(videoId);

  if (!vttPath) {
    return null;
  }

  const vttRaw = fs.readFileSync(vttPath, 'utf8');
  const transcript = cleanVttToTranscript(vttRaw);

  if (!transcript) {
    return null;
  }

  fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  const outputPath = path.join(
    OUTPUT_DIR,
    `transcript_${videoId}_clean.txt`,
  );

  fs.writeFileSync(outputPath, transcript, 'utf8');

  return outputPath;
}

function main() {
  const videoId = process.argv[2];

  if (!videoId) {
    console.error(
      'Cách dùng: node tools/extract_youtube_transcript.js <videoId>',
    );
    process.exitCode = 1;
    return;
  }

  console.log(`Đang lấy transcript cho video ${videoId}...`);

  const outputPath = extractTranscriptForVideo(videoId);

  if (!outputPath) {
    console.error(
      `Không lấy được caption tiếng Anh cho video ${videoId}.`,
    );
    process.exitCode = 1;
    return;
  }

  const transcript = fs.readFileSync(outputPath, 'utf8');

  console.log(`\nĐã lưu: ${outputPath}`);
  console.log(`Độ dài: ${transcript.length} ký tự.`);
  console.log(`\n--- Vài dòng đầu ---\n${transcript.slice(0, 300)}`);
}

if (require.main === module) {
  main();
}

module.exports = { extractTranscriptForVideo, cleanVttToTranscript };
