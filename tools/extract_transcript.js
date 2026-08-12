#!/usr/bin/env node
'use strict';

/**
 * Tải PDF transcript của bài "6 Minute English" từ BBC Learning English,
 * trích xuất text, làm sạch (bỏ header/footer/tên người nói/phần
 * Vocabulary) và xuất ra:
 *
 *   tools/output/transcript_clean.txt   - văn bản lời thoại đã làm sạch
 *   tools/output/transcript_words.json  - mảng các từ duy nhất (lowercase)
 *
 * Cách chạy:
 *   node tools/extract_transcript.js
 *
 * Có thể chỉ định PDF khác (ví dụ episode khác trong playlist) bằng cách
 * truyền URL làm tham số dòng lệnh:
 *   node tools/extract_transcript.js https://downloads.bbc.co.uk/.../xxx.pdf
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const { PDFParse } = require('pdf-parse');

// PDF transcript chính chủ từ BBC Learning English, mục "Download PDF"
// trên trang episode 6 Minute English - Learning multiple languages
// (https://www.bbc.co.uk/learningenglish/english/features/6-minute-english_2025/250410).
const DEFAULT_PDF_URL =
  'https://downloads.bbc.co.uk/learningenglish/features/6min/' +
  '250410_6_minute_english_learning_multiple_languages.pdf';

const DEFAULT_OUTPUT_NAME = '250410_learning_multiple_languages';

const TRANSCRIPTS_DIR = path.join(__dirname, 'transcripts');
const OUTPUT_DIR = path.join(__dirname, 'output');

const CLEAN_TXT_PATH = path.join(
  OUTPUT_DIR,
  'transcript_clean.txt',
);

const WORDS_JSON_PATH = path.join(
  OUTPUT_DIR,
  'transcript_words.json',
);

/** Tải file qua HTTPS, tự theo redirect, lưu trực tiếp ra đĩa. */
function downloadPdf(url, destPath) {
  return new Promise((resolve, reject) => {
    const request = https.get(
      url,
      {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (compatible; TranscriptFetcher/1.0)',
        },
      },
      (response) => {
        const isRedirect =
          response.statusCode &&
          response.statusCode >= 300 &&
          response.statusCode < 400 &&
          response.headers.location;

        if (isRedirect) {
          response.resume();
          downloadPdf(response.headers.location, destPath).then(
            resolve,
            reject,
          );
          return;
        }

        if (response.statusCode !== 200) {
          response.resume();
          reject(
            new Error(
              `Tải PDF thất bại, mã trạng thái HTTP ${response.statusCode}`,
            ),
          );
          return;
        }

        const fileStream = fs.createWriteStream(destPath);
        response.pipe(fileStream);

        fileStream.on('finish', () => {
          fileStream.close((closeError) => {
            if (closeError) {
              reject(closeError);
              return;
            }
            resolve();
          });
        });

        fileStream.on('error', reject);
      },
    );

    request.on('error', reject);
  });
}

// Các dòng đánh dấu "hết phần header, bắt đầu nội dung thật".
// BBC không phải lúc nào cũng có tiêu đề "Introduction" - transcript
// của nhiều episode 6 Minute English bắt đầu thẳng bằng lời thoại sau
// dòng "This is not a word-for-word transcript.", nên kiểm tra cả hai.
const HEADER_END_MARKERS = [
  /this is not a word-for-word transcript\.?/i,
  /^introduction$/i,
];

// Các dòng lặp lại ở đầu/cuối mỗi trang PDF, không phải nội dung thật.
const NOISE_LINE_PATTERNS = [
  /©\s*british broadcasting corporation/i,
  /bbclearningenglish\.com/i,
  /^--\s*\d+\s*of\s*\d+\s*--$/i,
  /^page\s+\d+\s+of\s+\d+/i,
  /^bbc learning english$/i,
  /^6 minute english\s*$/i,
];

// Dòng chỉ chứa tên người nói (ví dụ "Neil", "Hannah",
// "Frederique Liegeois") - viết hoa chữ đầu mỗi từ, không có dấu câu,
// đứng riêng một dòng ngay trước lời thoại của người đó.
const SPEAKER_NAME_LINE =
  /^[A-Z][a-zA-Z'’]*(?:\s[A-Z][a-zA-Z'’]*){0,3}$/;

/** Làm sạch text thô lấy từ PDF, trả về đoạn lời thoại thuần túy. */
function cleanTranscript(rawText) {
  const lines = rawText
    .split(/\r?\n/)
    .map((line) => line.trim());

  // Cắt bỏ header: giữ nội dung từ SAU dòng đánh dấu cuối cùng khớp
  // với HEADER_END_MARKERS (phòng trường hợp có cả hai dòng đánh dấu).
  let startIndex = 0;

  for (let i = 0; i < lines.length; i++) {
    const isHeaderEndMarker = HEADER_END_MARKERS.some(
      (pattern) => pattern.test(lines[i]),
    );

    if (isHeaderEndMarker) {
      startIndex = i + 1;
    }
  }

  // Cắt bỏ phần "Vocabulary" ở cuối: tìm dòng "Vocabulary" đứng riêng
  // gần cuối văn bản, bỏ mọi thứ từ đó về sau.
  let endIndex = lines.length;

  for (let i = startIndex; i < lines.length; i++) {
    if (/^vocabulary$/i.test(lines[i])) {
      endIndex = i;
      break;
    }
  }

  const contentLines = lines
    .slice(startIndex, endIndex)
    .filter((line) => {
      if (line.length === 0) {
        return false;
      }

      const isNoise = NOISE_LINE_PATTERNS.some((pattern) =>
        pattern.test(line),
      );

      if (isNoise) {
        return false;
      }

      if (SPEAKER_NAME_LINE.test(line)) {
        return false;
      }

      return true;
    });

  return contentLines.join(' ').replace(/\s+/g, ' ').trim();
}

/** Tách văn bản thành mảng từ duy nhất, lowercase, không dấu câu. */
function extractWords(cleanText) {
  const matches = cleanText.match(/[a-zA-Z']+/g) || [];

  const uniqueWords = new Set(
    matches.map((word) => word.toLowerCase()),
  );

  return Array.from(uniqueWords).sort();
}

async function main() {
  const customUrl = process.argv[2];
  const pdfUrl = customUrl || DEFAULT_PDF_URL;

  const outputName =
    process.argv[3] ||
    (customUrl
      ? path.basename(pdfUrl, '.pdf')
      : DEFAULT_OUTPUT_NAME);

  const pdfPath = path.join(
    TRANSCRIPTS_DIR,
    `${outputName}.pdf`,
  );

  fs.mkdirSync(TRANSCRIPTS_DIR, { recursive: true });
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  console.log(`Đang tải PDF transcript từ:\n${pdfUrl}`);

  await downloadPdf(pdfUrl, pdfPath);

  console.log(`Đã lưu PDF vào: ${pdfPath}`);

  const pdfBuffer = fs.readFileSync(pdfPath);
  const parser = new PDFParse({ data: pdfBuffer });
  const result = await parser.getText();
  await parser.destroy();

  const cleanText = cleanTranscript(result.text);
  const words = extractWords(cleanText);

  if (words.length === 0) {
    throw new Error(
      'Không trích được từ nào - kiểm tra lại cấu trúc PDF, có thể ' +
        'BBC đã đổi định dạng transcript.',
    );
  }

  fs.writeFileSync(CLEAN_TXT_PATH, cleanText, 'utf8');

  fs.writeFileSync(
    WORDS_JSON_PATH,
    JSON.stringify(words, null, 2),
    'utf8',
  );

  console.log(`\nĐã trích được ${words.length} từ duy nhất.`);

  console.log(
    '\n--- Vài dòng đầu ---\n' + cleanText.slice(0, 300),
  );

  console.log(
    '\n--- Vài dòng cuối ---\n' + cleanText.slice(-300),
  );

  console.log(
    `\nFile kết quả:\n- ${CLEAN_TXT_PATH}\n- ${WORDS_JSON_PATH}`,
  );
}

main().catch((error) => {
  console.error('Lỗi:', error.message);
  process.exitCode = 1;
});
