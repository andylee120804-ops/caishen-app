/**
 * 测试：Qwen-Image-Edit 是否支持 strength（低强度才能保住入图姿态）。
 * 用已知"伏地"的 f31 入图，提示词只要求换风格、严禁改姿态，测强度 0.4。
 * 输出 scripts/test-31.png，再用 python 量 rembg bbox 高度判断是否仍伏地。
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const IN = resolve(__dirname, 'kowtow-hd-src/f31.png'); // 奶油底伏地源帧
const b64 = 'data:image/png;base64,' + readFileSync(IN).toString('base64');

const prompt = 'Re-render this EXACT same character and pose: keep the identical silhouette, pose, back view, size and position. ' +
  'Only upgrade the art style to premium soft 3D chibi collectible figure: smooth glossy surfaces, soft studio lighting, ' +
  'rich shading and highlights, vibrant saturated colors, red Hanfu robe with gold trim. Do NOT alter the pose or orientation.';

const body = {
  model: 'Qwen/Qwen-Image-Edit-2509',
  prompt,
  image: b64,
  image_size: '1024x1024',
  strength: 0.4,
};

const res = await fetch('https://api.siliconflow.cn/v1/images/generations', {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${KEY}`, 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
});
const data = await res.json();
console.log('HTTP', res.status);
if (res.ok && data.images && data.images[0]) {
  const url = data.images[0].url ?? data.images[0].b64_json;
  const buf = url.startsWith('data:') ? Buffer.from(url.split(',')[1], 'base64') : Buffer.from(await (await fetch(url)).arrayBuffer());
  writeFileSync(resolve(__dirname, 'test-31.png'), buf);
  console.log('saved test-31.png', buf.length);
} else {
  console.log(JSON.stringify(data).slice(0, 500));
}
