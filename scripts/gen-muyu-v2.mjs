// 求签桶 v2 候选生成（Qwen-Image，2 个种子构图），输出 _v2 待抠图
import { writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = resolve(__dirname, '../entry/src/main/resources/rawfile/props/_v2_muyu');

const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const API = 'https://api.siliconflow.cn/v1/images/generations';

const STYLE =
  'Traditional Chinese temple wooden fish percussion instrument (muyu), ' +
  'carved from dark lacquered red-brown wood with golden cloud and lotus patterns, ' +
  'glossy lacquer finish, rounded fish shape with carved scales and open mouth slit, ' +
  'with a wooden mallet resting beside it, warm soft lighting, ' +
  'centered, no text no characters, clean solid light cream background, ' +
  'high quality digital painting, jewelry-like craftsmanship';

const CANDIDATES = [
  { file: 'muyu_a.jpg', seed: 401, prompt: 'front three-quarter view, dignified symmetrical temple atmosphere, rich wood grain and gold inlay' },
  { file: 'muyu_b.jpg', seed: 402, prompt: 'slightly angled side view with the mallet prominently leaning, lively warm atmosphere' },
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