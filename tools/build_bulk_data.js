#!/usr/bin/env node
'use strict';

/**
 * Gom transcript + tieu de + metadata da chuan bi thanh 1 file JSON
 * duy nhat de tools/bulk_add_listening.js doc va dien vao form Admin.
 */

const fs = require('fs');
const path = require('path');

const OUTPUT_DIR = path.join(__dirname, 'output');

const titles = JSON.parse(
  fs.readFileSync(path.join(OUTPUT_DIR, 'video_titles.json'), 'utf8'),
);

const VIDEOS = [
  {
    videoId: 'EdIQd86YQa0',
    description:
      'Podcast hội thoại tiếng Anh thực tế, luyện phản xạ giao tiếp tự nhiên trong các tình huống hàng ngày.',
    level: 'intermediate',
    speakingPrompt:
      'Real conversation is listening, reacting, and building from what you hear.',
  },
  {
    videoId: 'TT7u84ReKso',
    description:
      'Podcast hội thoại tiếng Anh B1-B2, hướng dẫn cách duy trì cuộc trò chuyện tự nhiên và tự tin hơn.',
    level: 'intermediate',
    speakingPrompt:
      "The conversations I remember most aren't always the clever ones.",
  },
  {
    videoId: '9enSIjZg8co',
    description:
      'Hội thoại tiếng Anh đơn giản, chậm rãi về chủ đề công việc mơ ước, phù hợp người mới học.',
    level: 'beginner',
    speakingPrompt: 'My dream job is being a travel photographer.',
  },
  {
    videoId: '1UycXtPI33U',
    description:
      'Podcast tiếng Anh dễ nghe dành cho người mới bắt đầu, chia sẻ bí quyết thay đổi bản thân từng ngày.',
    level: 'beginner',
    speakingPrompt: 'today I was a little better than yesterday',
  },
  {
    videoId: 'o8JuVJ4J3y0',
    description:
      'Hội thoại tiếng Anh trình độ A1 về chủ đề gọi món tại quán cà phê, luyện nghe cơ bản.',
    level: 'beginner',
    speakingPrompt: 'What do you want to eat and drink today?',
  },
  {
    videoId: 'jUmQVe4AbHk',
    description:
      'Podcast tiếng Anh nâng cao, hướng dẫn cách giới thiệu bản thân và trò chuyện tự tin, tự nhiên.',
    level: 'advanced',
    speakingPrompt:
      'Right, a good introduction gives people something to hold on to, something to respond to.',
  },
  {
    videoId: 'gv-JUVsU_hw',
    description:
      'Podcast tiếng Anh B1-B2 bàn về thói quen dậy sớm và giá trị của những phút yên tĩnh buổi sáng.',
    level: 'intermediate',
    speakingPrompt:
      'Sometimes the healthiest thing you can do is simply slow down.',
  },
  {
    videoId: 'y_FmbGdUSao',
    description:
      'Hội thoại tiếng Anh thực tế về chủ đề sân bay: check-in, an ninh, và lên máy bay.',
    level: 'beginner',
    speakingPrompt: 'Airports are full of interesting things to talk about.',
  },
  {
    videoId: '68w4SCbKwLo',
    description:
      "Podcast tiếng Anh B1-B2, chia sẻ cách xây dựng một 'ngày năng lượng' tích cực bằng các thói quen nhỏ.",
    level: 'intermediate',
    speakingPrompt: 'Every small movement slowly builds up your energy.',
  },
  {
    videoId: 'XtULXfqMdrE',
    description:
      'Video tiếng Anh dạng kể chuyện, truyền động lực luyện nói tiếng Anh mỗi ngày để tự tin hơn.',
    level: 'beginner',
    speakingPrompt:
      'Remember, every fluent speaker started exactly where you are today.',
  },
];

const result = VIDEOS.map((video) => {
  const transcriptPath = path.join(
    OUTPUT_DIR,
    `transcript_${video.videoId}_clean.txt`,
  );

  const transcript = fs.readFileSync(transcriptPath, 'utf8');
  const title = titles[video.videoId];

  if (!title) {
    throw new Error(`Thiếu tiêu đề cho video ${video.videoId}`);
  }

  if (!transcript.includes(video.speakingPrompt)) {
    throw new Error(
      `Câu gợi ý luyện nói không khớp verbatim với transcript: ${video.videoId}`,
    );
  }

  return {
    videoId: video.videoId,
    title,
    description: video.description,
    level: video.level,
    speakingPrompt: video.speakingPrompt,
    transcript,
  };
});

fs.writeFileSync(
  path.join(OUTPUT_DIR, 'bulk_listening_data.json'),
  JSON.stringify(result, null, 2),
  'utf8',
);

console.log(`Đã ghi ${result.length} video vào output/bulk_listening_data.json`);
