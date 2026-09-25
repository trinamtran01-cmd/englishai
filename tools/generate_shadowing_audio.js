// Sinh giọng đọc tự nhiên (Gemini TTS) cho 10 câu ĐẦU TIÊN của chủ đề
// Shadowing "Đàm phán & thương lượng" — thử nghiệm trong gói miễn phí.
//
// File audio được lưu ở web/shadowing_audio/ và phục vụ qua Firebase
// Hosting (miễn phí), KHÔNG dùng Firebase Storage (cần gói Blaze).
//
// Cách chạy (tài khoản admin truyền qua biến môi trường, không lưu file):
//   1) ADMIN_EMAIL=... ADMIN_PASSWORD=... node tools/generate_shadowing_audio.js generate
//   2) flutter build web && cp -r web/shadowing_audio web/writing_task_images build/web/
//      && firebase deploy --only hosting
//   3) ADMIN_EMAIL=... ADMIN_PASSWORD=... node tools/generate_shadowing_audio.js update
//
// Giai đoạn generate bỏ qua câu đã có file WAV để chạy lại không tốn
// thêm lượt gọi API; dừng ngay khi gặp giới hạn quota theo ngày.

const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'english-ai-app-9b33e';
const WEB_API_KEY = 'AIzaSyCzHdj80CuwkCe4UxO_ylA34giyy60euyo';
const HOSTING_BASE = `https://${PROJECT_ID}.web.app/shadowing_audio`;
const LESSON_TITLE_KEYWORD = 'Đàm phán';
const SEGMENT_LIMIT = 10;
const FILE_PREFIX = 'negotiation';
const TTS_MODEL = 'gemini-3.8-flash-tts';
const TTS_VOICE = 'Kore';
const TTS_STYLE =
  'clear, natural native American English, calm moderate pace, like a friendly teacher reading a sentence for language learners';
const GAP_BETWEEN_CALLS_MS = 7000;

const ROOT = path.resolve(__dirname, '..');
const AUDIO_DIR = path.join(ROOT, 'web', 'shadowing_audio');
const MANIFEST_PATH = path.join(AUDIO_DIR, 'manifest.json');
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

function readGeminiKey() {
  const env = fs.readFileSync(path.join(ROOT, '.env'), 'utf8');
  const match = env.match(/^GEMINI_API_KEY=(.*)$/m);
  if (!match || !match[1].trim()) throw new Error('Thiếu GEMINI_API_KEY trong .env');
  return match[1].trim();
}

async function signIn() {
  const email = process.env.ADMIN_EMAIL;
  const password = process.env.ADMIN_PASSWORD;
  if (!email || !password) throw new Error('Cần biến môi trường ADMIN_EMAIL và ADMIN_PASSWORD');
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${WEB_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  const body = await res.json();
  if (!res.ok) throw new Error(`Đăng nhập thất bại: ${JSON.stringify(body.error)}`);
  return body.idToken;
}

async function runQuery(idToken, collectionId, field, value) {
  const res = await fetch(`${FIRESTORE_BASE}:runQuery`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${idToken}` },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId }],
        ...(field
          ? { where: { fieldFilter: { field: { fieldPath: field }, op: 'EQUAL', value: { stringValue: value } } } }
          : {}),
      },
    }),
  });
  const rows = await res.json();
  if (!res.ok) throw new Error(`Query ${collectionId} lỗi: ${JSON.stringify(rows)}`);
  return rows.filter((r) => r.document).map((r) => r.document);
}

const str = (doc, f) => (doc.fields[f] && doc.fields[f].stringValue) || '';
const int = (doc, f) => {
  const v = doc.fields[f];
  return v ? Number(v.integerValue ?? v.doubleValue ?? 0) : 0;
};
const docId = (doc) => doc.name.split('/').pop();

async function loadTargetSegments(idToken) {
  const lessons = (await runQuery(idToken, 'shadowing_lessons')).filter((d) =>
    str(d, 'title').includes(LESSON_TITLE_KEYWORD),
  );
  if (lessons.length !== 1) {
    throw new Error(
      `Cần đúng 1 bài chứa "${LESSON_TITLE_KEYWORD}", tìm thấy ${lessons.length}: ` +
        lessons.map((d) => `${str(d, 'title')} (${docId(d)})`).join(', '),
    );
  }
  const lesson = lessons[0];
  const segments = (await runQuery(idToken, 'shadowing_segments', 'lessonId', docId(lesson)))
    .sort((a, b) => int(a, 'order') - int(b, 'order'))
    .slice(0, SEGMENT_LIMIT);
  console.log(`Bài: "${str(lesson, 'title')}" (${docId(lesson)}) — lấy ${segments.length} câu đầu`);
  return segments.map((d, i) => ({
    segmentId: docId(d),
    order: int(d, 'order'),
    text: str(d, 'text'),
    file: `${FILE_PREFIX}_${String(i + 1).padStart(2, '0')}.wav`,
  }));
}

// Bọc PCM16 24kHz mono thành WAV nếu API trả về dữ liệu thô không có header.
function ensureWav(buf) {
  if (buf.subarray(0, 4).toString('ascii') === 'RIFF') return buf;
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + buf.length, 4);
  header.write('WAVEfmt ', 8);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(24000, 24);
  header.writeUInt32LE(48000, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36);
  header.writeUInt32LE(buf.length, 40);
  return Buffer.concat([header, buf]);
}

async function synthesize(geminiKey, text) {
  const res = await fetch('https://generativelanguage.googleapis.com/v1beta/interactions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': geminiKey },
    body: JSON.stringify({
      model: TTS_MODEL,
      input: [
        {
          type: 'user_input',
          content: [{ type: 'text', text, annotations: [{ type: 'speech_metadata', style: TTS_STYLE }] }],
        },
      ],
      response_format: { type: 'audio' },
      generation_config: { speech_config: [{ voice: TTS_VOICE }] },
    }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(`HTTP ${res.status}: ${JSON.stringify(body.error || body).slice(0, 600)}`);
    err.status = res.status;
    err.perDay = /PerDay/i.test(JSON.stringify(body));
    throw err;
  }
  const audio = (body.steps || [])
    .filter((s) => s.type === 'model_output')
    .flatMap((s) => s.content || [])
    .filter((c) => c.type === 'audio')
    .pop();
  if (!audio || !audio.data) throw new Error(`Phản hồi không có audio: ${JSON.stringify(body).slice(0, 400)}`);
  return ensureWav(Buffer.from(audio.data, 'base64'));
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function generate() {
  const geminiKey = readGeminiKey();
  const idToken = await signIn();
  const targets = await loadTargetSegments(idToken);
  fs.mkdirSync(AUDIO_DIR, { recursive: true });
  fs.writeFileSync(MANIFEST_PATH, JSON.stringify(targets, null, 2));

  let calls = 0;
  const started = Date.now();
  for (const t of targets) {
    const out = path.join(AUDIO_DIR, t.file);
    if (fs.existsSync(out)) {
      console.log(`  [bỏ qua] ${t.file} đã có sẵn`);
      continue;
    }
    for (let attempt = 1; attempt <= 2; attempt++) {
      try {
        if (calls > 0) await sleep(GAP_BETWEEN_CALLS_MS);
        calls++;
        const wav = await synthesize(geminiKey, t.text);
        fs.writeFileSync(out, wav);
        const seconds = (wav.length - 44) / 48000;
        console.log(`  [OK] ${t.file} (${seconds.toFixed(1)}s) — "${t.text}"`);
        break;
      } catch (e) {
        console.log(`  [LỖI] ${t.file}: ${e.message}`);
        if (e.status === 429 && e.perDay) {
          console.log('Hết quota theo NGÀY — dừng, không gọi tiếp.');
          return summary(targets, calls, started);
        }
        if (e.status === 429 && attempt === 1) {
          console.log('  Giới hạn theo phút — chờ 65 giây rồi thử lại 1 lần...');
          await sleep(65000);
          continue;
        }
        break;
      }
    }
  }
  summary(targets, calls, started);
}

function summary(targets, calls, started) {
  const done = targets.filter((t) => fs.existsSync(path.join(AUDIO_DIR, t.file))).length;
  console.log(`\nXong: ${done}/${targets.length} câu có audio; ${calls} lần gọi API; ${((Date.now() - started) / 1000).toFixed(0)} giây.`);
}

async function update() {
  const targets = JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8'));
  const idToken = await signIn();
  for (const t of targets) {
    if (!fs.existsSync(path.join(AUDIO_DIR, t.file))) {
      console.log(`  [bỏ qua] ${t.file} chưa có audio — giữ nguyên flutter_tts`);
      continue;
    }
    const url = `${HOSTING_BASE}/${t.file}`;
    const head = await fetch(url, { method: 'HEAD' });
    const type = head.headers.get('content-type') || '';
    if (!head.ok || !type.startsWith('audio')) {
      console.log(`  [bỏ qua] ${url} chưa phục vụ được (HTTP ${head.status}, ${type}) — deploy hosting trước`);
      continue;
    }
    const res = await fetch(
      `${FIRESTORE_BASE}/shadowing_segments/${t.segmentId}?updateMask.fieldPaths=audioUrl&currentDocument.exists=true`,
      {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${idToken}` },
        body: JSON.stringify({ fields: { audioUrl: { stringValue: url } } }),
      },
    );
    console.log(res.ok ? `  [OK] câu ${t.order} → ${url}` : `  [LỖI] ${t.segmentId}: ${await res.text()}`);
  }
}

const phase = process.argv[2];
(phase === 'generate' ? generate() : phase === 'update' ? update() : Promise.reject(new Error('Dùng: generate | update')))
  .catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
