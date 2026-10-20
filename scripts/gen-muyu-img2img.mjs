// 木鱼保形重绘：以原始素材（合成米色底）为底图做 img2img（Qwen/Qwen-Image image 输入），
// 保持轮廓不变，仅升级绘制质感。输出 _v2_muyu/muyu_i2i_{a,b}.jpg
import { readFileSync } from 'node:fs';
import { writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = resolve(__dirname, '../entry/src/main/resources/rawfile/props/_v2_muyu');
const SRC = resolve(__dirname, '../tools_in/muyu_src_bg.png');
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const API = 'https://api.siliconflow.cn/v1/images/generations';

const PROMPT =
  'Redraw this exact same wooden fish percussion instrument (muyu), keeping the IDENTICAL silhouette, ' +
  'outline and overall proportions unchanged. Only upgrade the rendering quality: glossy dark-red lacquer ' +
  'finish, delicate golden inlay cloud patterns and carved fish scales, warm soft lighting, subtle 3D shading, ' +
  'single object centered on a clean solid light cream background, professional digital painting, no text no characters';

const CANDIDATES = [
  { file: 'muyu_i2i_a.jpg', seed: 501 },
  { file: 'muyu_i2i_b.jpg', seed: 502 },
];

const srcB64 = readFileSync(SRC).toString('base64');

async function generateOne(c) {
  const body = {
    model: 'Qwen/Qwen-Image',
    prompt: PROMPT,
    image: srcB64,
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
    throw new Error(`HTTP ${res.status}: ${JSON.stringify(data).slice(0, 300)}`);
  }
  const b64 = data.images[0].url ?? data.images[0].b64_json;
  const buf = b64.startsWith('data:')
    ? Buffer.from(b64.split(',')[1], 'base64')
    : Buffer.from(await (await fetch(b64)).arrayBuffer());
  const out = resolve(OUT_DIR, c.file);
  await writeFile(out, buf);
  console.log(`  ✓ ${out} (${(buf.length / 1024).toFixed(0)} KB, ${Date.now() - t}ms)`);
}

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