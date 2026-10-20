// 求签桶 v2 候选生成（Qwen-Image，2 个种子构图），输出 _v2 待抠图
import { writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = resolve(__dirname, '../entry/src/main/resources/rawfile/props/_v2_qiu');

const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const API = 'https://api.siliconflow.cn/v1/images/generations';

const STYLE =
  'Vertical composition, a traditional Chinese temple fortune-stick tube (qiutong), ' +
  'ornate red lacquered wooden cylinder with golden cloud patterns and gold bottom rim, ' +
  'filled with many bamboo fortune sticks (red and natural color) fanned out from the mouth, ' +
  'a pair of red crescent moon blocks (jiaobei) resting at the front left side, ' +
  'small golden ingot at the right bottom, rich glossy detail, warm lighting, ' +
  'centered, no text no characters, clean solid light cream background, ' +
  'high quality digital painting, jewelry-like craftsmanship';

const CANDIDATES = [
  { file: 'tube_a.jpg', seed: 301, prompt: 'front view, tube standing upright, sticks slightly fanned, dignified temple atmosphere' },
  { file: 'tube_b.jpg', seed: 302, prompt: 'slight low angle view, sticks dramatically fanned out like a bouquet, festive lively atmosphere' },
];

async function generateOne(c) {
  const body = {
    model: 'Qwen/Qwen-Image',
    prompt: `${STYLE}. ${c.prompt}.`,
    image_size: '1024x1024',
    seed: c.seed,
  };
  console.log(`▶ ${c.file} seed=${c.seed}`);
  const t = Date.now();
  const res = await fetch(API, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok || !data.images || !data.images.length) {
    throw new Error(`HTTP ${res.status}: ${JSON.stringify(data).slice(0, 240)}`);
  }
  const b64 = data.images[0].url ?? data.images[0].b64_json;
  const buf = b64.startsWith('data:')
    ? Buffer.from(b64.split(',')[1], 'base64')
    : Buffer.from(await (await fetch(b64)).arrayBuffer());
  const out = resolve(OUT_DIR, c.file);
  await writeFile(out, buf);
  console.log(`  ✓ ${out} (${(buf.length / 1024).toFixed(0)} KB, ${Date.now() - t}ms)`);
}

async function main() {
  await mkdir(OUT_DIR, { recursive: true });
  for (const c of CANDIDATES) {
    try {
      await generateOne(c);
      await new Promise(r => setTimeout(r, 3000));
    } catch (e) {
      console.error(`  ✗ ${c.file} failed:`, e.message);
    }
  }
  console.log('done');
}

main();