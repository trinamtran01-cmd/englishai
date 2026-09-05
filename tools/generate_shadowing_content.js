#!/usr/bin/env node
'use strict';

/**
 * Sinh 20 chu de Shadowing x 20 cau/chu de bang Gemini API, ghi
 * thang vao Firestore qua REST API (dang nhap REST bang tai khoan
 * Admin de lay idToken, khong dung Playwright/UI vi form segment
 * chi cho them tung cau 1, qua cham cho 400 cau).
 *
 * Cach chay:
 *   ADMIN_EMAIL=... ADMIN_PASSWORD=... node tools/generate_shadowing_content.js
 *
 * Tuy chon: truyen danh sach index chu de (0-based, cach nhau dau
 * phay) qua bien moi truong TOPICS_ONLY de chi chay thu 1 vai chu de
 * (vi du TOPICS_ONLY=0,1 chi sinh 2 chu de dau tien).
 */

const fs = require('fs');
const path = require('path');

const ADMIN_EMAIL = process.env.ADMIN_EMAIL;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD;

if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
  console.error('Thiếu ADMIN_EMAIL / ADMIN_PASSWORD trong biến môi trường.');
  process.exit(1);
}

const PROJECT_ID = 'english-ai-app-9b33e';
const FIREBASE_WEB_API_KEY = 'AIzaSyCzHdj80CuwkCe4UxO_ylA34giyy60euyo';
const GEMINI_MODEL = 'gemini-3.5-flash-lite';

const SENTENCES_PER_LESSON = 20;

function loadGeminiApiKey() {
  const envPath = path.join(__dirname, '..', '.env');
  const envText = fs.readFileSync(envPath, 'utf8');

  for (const line of envText.split(/\r?\n/)) {
    const match = line.match(/^GEMINI_API_KEY\s*=\s*(.+)$/);
    if (match) {
      return match[1].trim();
    }
  }

  throw new Error('Không tìm thấy GEMINI_API_KEY trong .env');
}

const GEMINI_API_KEY = loadGeminiApiKey();

// 20 chu de luyen Shadowing - da bo trung "nha hang/ca phe" thanh 2
// chu de tach biet (goi mon nha hang vs. tro chuyen quan ca phe) so
// voi danh sach goi y ban dau de tranh trung lap noi dung.
const TOPICS = [
  { key: 'workplace', title: 'Giao tiếp nơi công sở', level: 'intermediate', themeColor: '#4A6FA5', iconName: 'workplace' },
  { key: 'restaurant', title: 'Gọi món tại nhà hàng', level: 'intermediate', themeColor: '#E67E22', iconName: 'restaurant' },
  { key: 'airport', title: 'Ở sân bay', level: 'intermediate', themeColor: '#2E86AB', iconName: 'flight' },
  { key: 'interview', title: 'Phỏng vấn xin việc', level: 'advanced', themeColor: '#6C5CE7', iconName: 'badge' },
  { key: 'shopping', title: 'Mua sắm', level: 'beginner', themeColor: '#E84393', iconName: 'shopping_bag' },
  { key: 'directions', title: 'Hỏi đường', level: 'beginner', themeColor: '#00B894', iconName: 'map' },
  { key: 'phone', title: 'Gọi điện thoại', level: 'beginner', themeColor: '#0984E3', iconName: 'call' },
  { key: 'introduction', title: 'Giới thiệu bản thân', level: 'beginner', themeColor: '#E1A100', iconName: 'person' },
  { key: 'weather', title: 'Thời tiết', level: 'beginner', themeColor: '#74B9FF', iconName: 'weather' },
  { key: 'health', title: 'Sức khỏe & khám bệnh', level: 'intermediate', themeColor: '#D63031', iconName: 'health' },
  { key: 'bank', title: 'Tại ngân hàng', level: 'intermediate', themeColor: '#34568B', iconName: 'bank' },
  { key: 'travel', title: 'Du lịch', level: 'intermediate', themeColor: '#00CEC9', iconName: 'travel' },
  { key: 'technology', title: 'Công nghệ hàng ngày', level: 'intermediate', themeColor: '#5352ED', iconName: 'technology' },
  { key: 'family', title: 'Gia đình', level: 'beginner', themeColor: '#FF7675', iconName: 'family' },
  { key: 'hobbies', title: 'Sở thích cá nhân', level: 'beginner', themeColor: '#F0932B', iconName: 'hobbies' },
  { key: 'sports', title: 'Thể thao', level: 'intermediate', themeColor: '#27AE60', iconName: 'sports' },
  { key: 'study', title: 'Học tập', level: 'intermediate', themeColor: '#2980B9', iconName: 'study' },
  { key: 'cafe', title: 'Trò chuyện ở quán cà phê', level: 'beginner', themeColor: '#6F4E37', iconName: 'cafe' },
  { key: 'apology', title: 'Xin lỗi & cảm ơn', level: 'intermediate', themeColor: '#E17055', iconName: 'apology' },
  { key: 'negotiation', title: 'Đàm phán & thương lượng', level: 'advanced', themeColor: '#636E72', iconName: 'negotiation' },
];

function log(message) {
  console.log(`[${new Date().toISOString()}] ${message}`);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Dang nhap Firebase Auth REST API, tra ve idToken. */
async function signInAdmin() {
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_WEB_API_KEY}`;

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD,
      returnSecureToken: true,
    }),
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error(
      `Đăng nhập Admin thất bại: ${data.error ? data.error.message : response.status}`,
    );
  }

  return data.idToken;
}

function buildPrompt(topicTitle) {
  return (
    `Bạn là một giáo viên tiếng Anh giàu kinh nghiệm, đang biên soạn ` +
    `tài liệu luyện "shadowing" (nghe và nhại lại câu) cho học viên ` +
    `Việt Nam.\n\n` +
    `Hãy TỰ SÁNG TÁC HOÀN TOÀN MỚI đúng ${SENTENCES_PER_LESSON} câu ` +
    `tiếng Anh ngắn (khoảng 6-15 từ mỗi câu), tự nhiên trong giao ` +
    `tiếp hàng ngày, độc lập với nhau (không phải một đoạn hội ` +
    `thoại liên tục), xoay quanh chủ đề: "${topicTitle}".\n\n` +
    `YÊU CẦU BẮT BUỘC: sáng tác câu hoàn toàn mới, KHÔNG được trích ` +
    `dẫn nguyên văn hoặc phỏng theo bất kỳ câu có sẵn nào từ sách, ` +
    `bài hát, kịch bản phim, chương trình TV, hay bất kỳ tác phẩm có ` +
    `bản quyền nào. Câu phải do bạn tự nghĩ ra, đơn giản, phù hợp để ` +
    `người học lặp lại theo (không quá dài, không dùng thành ngữ ` +
    `hiếm gặp).\n\n` +
    `Với mỗi câu, cung cấp thêm: phiên âm IPA chuẩn (đặt trong dấu ` +
    `/.../ ), và bản dịch tiếng Việt tự nhiên (không dịch máy móc ` +
    `từng từ).\n\n` +
    `Trả về DUY NHẤT một đối tượng JSON thuần túy, không dùng ` +
    `markdown, không code fence, không giải thích thêm, đúng cấu ` +
    `trúc sau:\n` +
    `{"sentences": [{"text": "...", "ipaPronunciation": "...", ` +
    `"vietnameseTranslation": "..."}]}\n` +
    `Mảng "sentences" phải có đúng ${SENTENCES_PER_LESSON} phần tử.`
  );
}

/** Boc tach JSON tu chuoi text, loai bo code fence neu co. */
function parseJsonFromText(rawText) {
  let cleanText = rawText.trim();

  if (cleanText.startsWith('```')) {
    cleanText = cleanText.replace(/^```(json)?/, '').trim();
    if (cleanText.endsWith('```')) {
      cleanText = cleanText.slice(0, -3).trim();
    }
  }

  return JSON.parse(cleanText);
}

async function callGeminiForSentences(topicTitle) {
  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/` +
    `${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;

  const requestBody = {
    contents: [{ parts: [{ text: buildPrompt(topicTitle) }] }],
  };

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(requestBody),
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error(
      `Gemini API lỗi (${response.status}): ${JSON.stringify(data).slice(0, 300)}`,
    );
  }

  const candidates = data.candidates;
  if (!candidates || candidates.length === 0) {
    throw new Error('Gemini không trả về candidates nào.');
  }

  const parts = candidates[0].content && candidates[0].content.parts;
  if (!parts || parts.length === 0) {
    throw new Error('Gemini không trả về nội dung.');
  }

  const rawText = parts[0].text || '';
  const parsed = parseJsonFromText(rawText);

  if (!parsed.sentences || !Array.isArray(parsed.sentences)) {
    throw new Error('JSON trả về thiếu mảng "sentences".');
  }

  const validSentences = parsed.sentences.filter(
    (item) =>
      item &&
      typeof item.text === 'string' &&
      item.text.trim().length > 0,
  );

  if (validSentences.length === 0) {
    throw new Error('Không có câu hợp lệ nào trong kết quả.');
  }

  return validSentences;
}

/** Chuyen 1 object JS phang thanh Firestore REST "fields" format. */
function toFirestoreFields(obj) {
  const fields = {};

  for (const [key, value] of Object.entries(obj)) {
    if (typeof value === 'string') {
      fields[key] = { stringValue: value };
    } else if (typeof value === 'number' && Number.isInteger(value)) {
      fields[key] = { integerValue: String(value) };
    } else if (value instanceof Date) {
      fields[key] = { timestampValue: value.toISOString() };
    } else {
      throw new Error(`Kiểu dữ liệu không hỗ trợ cho field "${key}"`);
    }
  }

  return { fields };
}

async function createDocument(idToken, collection, dataObject) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}` +
    `/databases/(default)/documents/${collection}`;

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${idToken}`,
    },
    body: JSON.stringify(toFirestoreFields(dataObject)),
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error(
      `Firestore lỗi khi tạo document trong "${collection}": ` +
        `${JSON.stringify(data).slice(0, 300)}`,
    );
  }

  // data.name dạng: projects/.../databases/(default)/documents/COLLECTION/DOC_ID
  const segments = data.name.split('/');
  return segments[segments.length - 1];
}

async function processTopic(idToken, topic, index, total) {
  log(`[${index + 1}/${total}] Đang gọi Gemini cho chủ đề: "${topic.title}"...`);

  const sentences = await callGeminiForSentences(topic.title);

  log(
    `[${index + 1}/${total}] Gemini trả về ${sentences.length} câu. ` +
      `Đang tạo lesson + segments trên Firestore...`,
  );

  const lessonId = await createDocument(idToken, 'shadowing_lessons', {
    title: topic.title,
    description: `Luyện nhại ${sentences.length} câu tiếng Anh tự nhiên về chủ đề "${topic.title}".`,
    level: topic.level,
    themeColor: topic.themeColor,
    iconName: topic.iconName,
    createdAt: new Date(),
  });

  let createdCount = 0;

  for (let i = 0; i < sentences.length; i++) {
    const sentence = sentences[i];

    await createDocument(idToken, 'shadowing_segments', {
      lessonId,
      order: i + 1,
      text: sentence.text.trim(),
      ipaPronunciation: (sentence.ipaPronunciation || '').trim(),
      vietnameseTranslation: (sentence.vietnameseTranslation || '').trim(),
    });

    createdCount++;
  }

  log(
    `[${index + 1}/${total}] ĐÃ TẠO: "${topic.title}" ` +
      `(lessonId=${lessonId}, ${createdCount} câu).`,
  );

  return { topic, lessonId, sentenceCount: createdCount };
}

async function main() {
  const topicsOnlyEnv = process.env.TOPICS_ONLY;
  const selectedTopics = topicsOnlyEnv
    ? topicsOnlyEnv.split(',').map((s) => TOPICS[Number(s.trim())])
    : TOPICS;

  log(`Sẽ xử lý ${selectedTopics.length}/${TOPICS.length} chủ đề.`);

  log('Đang đăng nhập Admin qua Firebase Auth REST...');
  const idToken = await signInAdmin();
  log('Đăng nhập thành công, đã có idToken.');

  const results = { success: [], failed: [] };

  for (let i = 0; i < selectedTopics.length; i++) {
    const topic = selectedTopics[i];

    try {
      const result = await processTopic(idToken, topic, i, selectedTopics.length);
      results.success.push(result);
    } catch (error) {
      log(`[${i + 1}/${selectedTopics.length}] LỖI ở chủ đề "${topic.title}": ${error.message}`);
      results.failed.push({ topic, error: error.message });
    }

    // Nghỉ ngắn giữa các chủ đề để tránh dồn quá nhiều request liên
    // tiếp tới Gemini API.
    await sleep(1500);
  }

  console.log('\n========== KẾT QUẢ ==========');
  console.log(`Thành công: ${results.success.length}/${selectedTopics.length} chủ đề`);

  let totalSentences = 0;
  for (const item of results.success) {
    totalSentences += item.sentenceCount;
    console.log(`  ✔ ${item.topic.title} — ${item.sentenceCount} câu (lessonId=${item.lessonId})`);
  }

  console.log(`Tổng số câu đã tạo: ${totalSentences}`);
  console.log(`Lỗi: ${results.failed.length}/${selectedTopics.length} chủ đề`);

  for (const item of results.failed) {
    console.log(`  ✘ ${item.topic.title}: ${item.error}`);
  }

  if (results.failed.length > 0) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error('Lỗi không mong đợi:', error);
  process.exitCode = 1;
});
