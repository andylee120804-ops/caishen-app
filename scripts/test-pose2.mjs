/**
 * 测试双图编辑：image1 = HD 站立底图(财神像风格/身份)，image2 = 源帧(精确姿态+背面视角)。
 * 期望：姿态与视角都锁定源帧(伏地+纯背面)，风格沿用 image1。测 image2 字段是否被采纳。
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const base = 'data:image/png;base64,' + readFileSync(resolve(__dirname, 'kowtow-hd-out/f01.png')).toString('base64');
const ref  = 'data:image/png;base64,' + readFileSync(resolve(__dirname, 'kowtow-hd-src/f31.png')).toString('base64');

const prompt = 'Repaint the character from image1 into the EXACT pose, silhouette and body orientation shown in image2. ' +
  'Match image2\'s viewpoint and camera angle precisely (back view looking at the character\'s back, character lying flat/prostrate on the ground). ' +
  'Keep image1\'s art style: premium soft 3D chibi collectible figure, smooth glossy surfaces, soft studio lighting, ' +
  'rich shading, vibrant colors, red Hanfu robe with gold trim, black topknot. Do NOT rotate the viewpoint and do NOT stand the figure up.';

const body = {
  model: 'Qwen/Qwen-Image-Edit-2509',
  prompt,
  image: base,
  image2: ref,
  image_size: '1024x1024',
  strength: 0.6,
};
console.log('sending image2 field...');
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
  writeFileSync(resolve(__dirname, 'test-31b.png'), buf);
  console.log('saved test-31b.png', buf.length);
} else {
  console.log(JSON.stringify(data).slice(0, 500));
}
